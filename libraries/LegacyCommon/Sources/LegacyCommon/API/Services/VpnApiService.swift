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

import Dependencies

import ProtonCoreFeatureFlags
import ProtonCoreNetworking
import ProtonCoreAuthentication
import ProtonCoreDataModel

import CommonNetworking
import Domain
import Ergonomics
import Persistence
import LocalFeatureFlags
import Localization
import VPNShared

public protocol VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService
}

extension Container: VpnApiServiceFactory {
    public func makeVpnApiService() -> VpnApiService {
        return VpnApiService(self)
    }
}

public enum ServerInfoResponse {
    case notModified(since: String)
    case modified(at: String?, servers: [ServerModel], freeServersOnly: Bool)
}

public class VpnApiService {
    @Dependency(\.serverRepository) var serverRepository
    public typealias Factory = NetworkingFactory & VpnKeychainFactory & CountryCodeProviderFactory & AuthKeychainHandleFactory

    public typealias ServerInfoTuple = (
        serverInfo: ServerInfoResponse?,
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
            serverInfo: try serverInfo(
                ip: (asyncLocation?.ip).flatMap { TruncatedIp(ip: $0) },
                countryCode: asyncLocation?.country,
                freeTier: asyncCredentials.maxTier.isFreeTier && serversAccordingToTier
            ),
            vpnCredentials: asyncCredentials,
            location: asyncLocation,
            clientConfig: clientConfig,
            user: try? userInfo(),
            addresses: try? userAddresses()
        )
    }

    public func refreshServerInfo(ifIpHasChangedFrom lastKnownIp: String? = nil, freeTier: Bool) async throws -> ServerInfoTuple? {
        let location = await userLocation()

        guard lastKnownIp == nil || location?.ip != lastKnownIp else {
            return nil
        }

        return await (
            serverInfo: try serverInfo(
                ip: (location?.ip).flatMap { TruncatedIp(ip: $0) },
                countryCode: location?.country,
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
            if error.httpCode == HttpStatusCode.accessForbidden.rawValue,
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
    public func serverInfo(
        ip: TruncatedIp?,
        countryCode: String?,
        freeTier: Bool,
        completion: @escaping (Result<ServerInfoResponse, Error>) -> Void
    ) {
        let countryCodes: [String] = (countryCode.map { [$0] } ?? []) // country code from v1/locations response
            .appending(countryCodeProvider.countryCodes) // local guesses at appropriate country codes
            .uniqued

        let shouldSendLastModifiedValue = FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.timestampedLogicals)
        let lastModifiedMetadataKey: DatabaseMetadata.Key = freeTier ? .lastModifiedFree : .lastModifiedAll
        let lastModified = serverRepository.getMetadata(lastModifiedMetadataKey)

        networking.request(
            LogicalsRequest(
                ip: ip,
                countryCodes: countryCodes,
                freeTier: freeTier,
                lastModified: shouldSendLastModifiedValue ? lastModified : nil
            )
        ) { (response: Result<IfModifiedSinceResponse<JSONDictionary>, Error>) in
            let result: Result<ServerInfoResponse, Error>
            defer { completion(result) }

            switch response {
            case .success(.notModified(let lastModified)):
                log.debug("Logicals unchanged since last request", metadata: ["lastModified": "\(lastModified)"])
                result = .success(.notModified(since: lastModified))

            case .success(.modified(let lastModified, let json)):
                guard let serversJson = json.jsonArray(key: "LogicalServers") else {
                    log.error("'Servers' field not present in server info request's response", category: .api, event: .response)
                    let error = ParseError.serverParse
                    result = .failure(error)
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
                result = .success(.modified(at: lastModified, servers: serverModels, freeServersOnly: freeTier))

            case let .failure(error):
                result = .failure(error)
            }
        }
    }

    public func serverInfo(ip: TruncatedIp?, countryCode: String?, freeTier: Bool) async throws -> ServerInfoResponse {
        return try await withCheckedThrowingContinuation { continuation in
            serverInfo(ip: ip, countryCode: countryCode, freeTier: freeTier, completion: continuation.resume(with:))
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
        do {
            return try await networking.perform(request: LocationRequest())
        } catch {
            log.error("Couldn't parse user's ip location response", category: .api, event: .response, metadata: ["error": "\(error)"])
            return nil
        }
    }

    public func sessionsCount() async throws -> SessionsResponse {
        try await networking.perform(request: VPNSessionsCountRequest())
    }
    
    public func loads(lastKnownIp: TruncatedIp?, completion: @escaping (Result<ContinuousServerPropertiesDictionary, Error>) -> Void) {
        let shortenedIp = lastKnownIp?.value
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

    public func userInfo() async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            Authenticator(api: networking.apiService).getUserInfo(completion: continuation.resume(with:))
        }
    }

    public func userAddresses() async throws -> [Address] {
        try await withCheckedThrowingContinuation { continuation in
            Authenticator(api: networking.apiService).getAddresses(completion: continuation.resume(with:))
        }
    }

}
