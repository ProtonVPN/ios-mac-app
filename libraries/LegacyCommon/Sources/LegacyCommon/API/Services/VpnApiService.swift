//
//  VpnApiService.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import ProtonCoreNetworking
import ProtonCoreAuthentication
import ProtonCoreDataModel

import Ergonomics
import LocalFeatureFlags
import VPNShared

public protocol VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService
}

extension Container: VpnApiServiceFactory {
    public func makeVpnApiService() -> VpnApiService {
        return VpnApiService(self)
    }
}

public class VpnApiService {
    public typealias Factory = NetworkingFactory & VpnKeychainFactory & CountryCodeProviderFactory & AuthKeychainHandleFactory

    public typealias ServerInfoTuple = (
        serverModels: [ServerModel],
        location: UserLocation?,
        streamingServices: VPNStreamingResponse?
    )

    private let networking: Networking
    private let vpnKeychain: VpnKeychainProtocol
    private let countryCodeProvider: CountryCodeProvider
    private let authKeychain: AuthKeychainHandle

    public init(networking: Networking, vpnKeychain: VpnKeychainProtocol, countryCodeProvider: CountryCodeProvider, authKeychain: AuthKeychainHandle) {
        self.networking = networking
        self.vpnKeychain = vpnKeychain
        self.countryCodeProvider = countryCodeProvider
        self.authKeychain = authKeychain
    }

    public convenience init(_ factory: Factory) {
        self.init(networking: factory.makeNetworking(),
                  vpnKeychain: factory.makeVpnKeychain(),
                  countryCodeProvider: factory.makeCountryCodeProvider(),
                  authKeychain: factory.makeAuthKeychainHandle())
    }

    public func vpnProperties(isDisconnected: Bool, 
                              lastKnownLocation: UserLocation?,
                              serversAccordingToTier: Bool) async throws -> VpnProperties {

        // Only retrieve IP address when not connected to VPN
        async let asyncLocation = (isDisconnected ? userLocation() : lastKnownLocation) ?? lastKnownLocation
        let clientConfig = try? await clientConfig(for: asyncLocation?.ip)
        let asyncCredentials = try await clientCredentials()

        return await VpnProperties(
            serverModels: try serverInfo(
                ip: asyncLocation?.ip,
                freeTier: asyncCredentials.maxTier.isFreeTier && serversAccordingToTier
            ),
            vpnCredentials: asyncCredentials,
            location: asyncLocation,
            clientConfig: clientConfig,
            user: try? userInfo()
        )
    }

    public func refreshServerInfo(ifIpHasChangedFrom lastKnownIp: String? = nil, freeTier: Bool) async throws -> ServerInfoTuple? {
        let location = await userLocation()

        guard lastKnownIp == nil || location?.ip != lastKnownIp else {
            return nil
        }

        return await (
            serverModels: try serverInfo(
                ip: location?.ip,
                freeTier: freeTier
            ),
            location: location,
            streamingServices: try? virtualServices()
        )
    }

    // swiftlint:disable:next large_tuple
    /// If the user IP has changed since the last connection, refresh the server information. This is a subset of what
    /// is returned from the `vpnProperties` method in the `VpnProperties` object, so just return an anonymous tuple.
    public func refreshServerInfo(
        ifIpHasChangedFrom lastKnownIp: String? = nil,
        freeTier: Bool,
        completion: @escaping (Result<ServerInfoTuple?, Error>
    ) -> Void) {
        Task {
            do {
                let prop = try await refreshServerInfo(ifIpHasChangedFrom: lastKnownIp, freeTier: freeTier)
                completion(.success(prop))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func clientCredentials() async throws -> VpnCredentials {
        guard authKeychain.username != nil else {
            throw VpnApiServiceError.endpointRequiresAuthentication
        }

        do {
            let json = try await networking.perform(request: VPNClientCredentialsRequest())
            return try VpnCredentials(dic: json)
        } catch {
            let error = error as NSError
            if error.httpCode == HttpStatusCode.accessForbidden,
               error.responseCode == ApiErrorCode.subuserWithoutSessions {
                throw ProtonVpnError.subuserWithoutSessions
            }
            if error.code != -1 {
                log.error("clientCredentials error", category: .api, event: .response, metadata: ["error": "\(error)"])
                throw error
            } else {
                log.error("Error occurred during user's VPN credentials parsing", category: .api, event: .response, metadata: ["error": "\(error)"])
                let error = ParseError.vpnCredentialsParse
                throw error
            }
        }
    }

    // The following route is used to retrieve VPN server information, including scores for the best server to connect to depending on a user's proximity to a server and its load. To provide relevant scores even when connected to VPN, we send a truncated version of the user's public IP address. In keeping with our no-logs policy, this partial IP address is not stored on the server and is only used to fulfill this one-off API request.
    public func serverInfo(ip: String?, freeTier: Bool, completion: @escaping (Result<[ServerModel], Error>) -> Void) {
        let shortenedIp = truncatedIp(ip)
        let countryCodes = countryCodeProvider.countryCodes

        networking.request(
            VPNLogicalServicesRequest(
                ip: shortenedIp,
                countryCodes: countryCodes,
                freeTier: freeTier
            )
        ) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                guard let serversJson = json.jsonArray(key: "LogicalServers") else {
                    log.error("'Servers' field not present in server info request's response", category: .api, event: .response)
                    let error = ParseError.serverParse
                    completion(.failure(error))
                    return
                }

                var serverModels: [ServerModel] = []
                for json in serversJson {
                    do {
                        serverModels.append(try ServerModel(dic: json))
                    } catch {
                        log.error("Failed to parse server info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(json)"])
                    }
                }
                completion(.success(serverModels))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func serverInfo(ip: String?, freeTier: Bool) async throws -> [ServerModel] {
        let shortenedIp = truncatedIp(ip)
        return try await withCheckedThrowingContinuation { continuation in
            serverInfo(ip: shortenedIp, freeTier: freeTier, completion: continuation.resume(with:))
        }
    }

    public func serverState(serverId id: String, completion: @escaping (Result<VpnServerState, Error>) -> Void) {
        networking.request(VPNServerRequest(id)) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let json = response.jsonDictionary(key: "Server"), let serverState = try? VpnServerState(dictionary: json)  else {
                    let error = ParseError.serverParse
                    log.error("'Server' field not present in server info request's response", category: .api, event: .response, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                    return
                }
                completion(.success(serverState))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func userLocation() async -> UserLocation? {
        return await withCheckedContinuation { continuation in
            userLocation { result in
                switch result {
                case .success(let success):
                    continuation.resume(with: .success(success))
                case .failure:
                    continuation.resume(with: .success(nil))
                }
            }
        }
    }

    public func userLocation(completion: @escaping (Result<UserLocation, Error>) -> Void) {
        networking.request(VPNLocationRequest()) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let userLocation = try? UserLocation(dic: response) else {
                    let error = ParseError.userIpParse
                    log.error("'IP' field not present in user's ip location response", category: .api, event: .response, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                    return
                }
                completion(.success(userLocation))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func sessionsCount() async throws -> SessionsResponse {
        try await networking.perform(request: VPNSessionsCountRequest())
    }
    
    public func loads(lastKnownIp: String?, completion: @escaping (Result<ContinuousServerPropertiesDictionary, Error>) -> Void) {
        var shortenedIp: String?
        if let ip = lastKnownIp {
            shortenedIp = truncatedIp(ip)
        }
        networking.request(VPNLoadsRequest(shortenedIp)) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                guard let loadsJson = response.jsonArray(key: "LogicalServers") else {
                    let error = ParseError.loadsParse
                    log.error("'LogicalServers' field not present in loads response", category: .api, event: .response, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                    return
                }

                var loads = ContinuousServerPropertiesDictionary()
                for json in loadsJson {
                    do {
                        let load = try ContinuousServerProperties(dic: json)
                        loads[load.serverId] = load
                    } catch {
                        log.error("Failed to parse load info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(json)"])
                    }
                }

                completion(.success(loads))
            case let .failure(error):
                completion(.failure(error))
            }

        }
    }
    
    public func clientConfig(for shortenedIp: String?, completion: @escaping (Result<ClientConfig, Error>) -> Void) {
        let request = VPNClientConfigRequest(isAuth: vpnKeychain.userIsLoggedIn,
                                             ip: shortenedIp)

        networking.request(request) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(response):
                do {
                    let data = try JSONSerialization.data(withJSONObject: response as Any, options: [])
                    let decoder = JSONDecoder()
                    // this strategy is decapitalizing first letter of response's labels to get appropriate name
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                    let clientConfigResponse = try decoder.decode(ClientConfigResponse.self, from: data)

                    if let overrides = clientConfigResponse.clientConfig.featureFlags.localOverrides {
                        setLocalFeatureFlagOverrides(overrides)
                    }
                    completion(.success(clientConfigResponse.clientConfig))

                } catch {
                    log.error("Failed to parse load info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(response)"])
                    let error = ParseError.loadsParse
                    completion(.failure(error))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func clientConfig(for shortenedIp: String?) async throws -> ClientConfig {
        try await withCheckedThrowingContinuation { continuation in
            clientConfig(for: shortenedIp, completion: continuation.resume(with:))
        }
    }

    public func virtualServices() async throws -> VPNStreamingResponse {
        try await networking.perform(request: VPNStreamingRequest())
    }

    public func partnersServices() async throws -> VPNPartnersResponse {
        try await networking.perform(request: VPNPartnersRequest())
    }

    public func userInfo() async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            Authenticator(api: networking.apiService).getUserInfo(completion: continuation.resume(with:))
        }
    }

    // MARK: - Private

    private func truncatedIp(_ ip: String?) -> String? {
        guard let ip else { return nil }
        // Remove the last octet
        if let index = ip.lastIndex(of: ".") { // IPv4
            return ip.replacingCharacters(in: index..<ip.endIndex, with: ".0")
        } else if let index = ip.lastIndex(of: ":") { // IPv6
            return ip.replacingCharacters(in: index..<ip.endIndex, with: "::")
        } else {
            return ip
        }
    }
}
