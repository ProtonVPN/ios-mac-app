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
import DependenciesMacros

import ProtonCoreAuthentication
import ProtonCoreDataModel

import Domain
import Ergonomics
import Persistence
import VPNShared

@DependencyClient
public struct VpnApiClient: Sendable {
    public internal(set) var vpnProperties: @Sendable (_ isDisconnected: Bool, _ lastKnownLocation: UserLocation?, _ serversAccordingToTier: Bool) async throws -> VpnProperties
    public internal(set) var refreshServerInfo: @Sendable (_ ifIpHasChangedFrom: String?, _ freeTier: Bool) async throws -> ServerInfoTuple?
    public internal(set) var clientCredentials: @Sendable () async throws -> VpnCredentials
    public internal(set) var serverInfo: @Sendable (_ ip: TruncatedIp?, _ countryCode: String?, _ freeTier: Bool) async throws -> ServerInfoResponse
    public internal(set) var serverState: @Sendable (_ serverId: String) async throws -> VpnServerState
    public internal(set) var userLocation: @Sendable () async -> UserLocation?
    public internal(set) var sessionsCount: @Sendable () async throws -> SessionsResponse
    public internal(set) var loads: @Sendable (_ lastKnownIp: TruncatedIp?) async throws -> ContinuousServerPropertiesDictionary
    public internal(set) var clientConfig: @Sendable (_ for: String?) async throws -> ClientConfig
    public internal(set) var virtualServices: @Sendable () async throws -> VPNStreamingResponse
    public internal(set) var userInfo: @Sendable () async throws -> User
    public internal(set) var userAddresses: @Sendable () async throws -> [Address]
}

public enum VpnApiClientKey: DependencyKey {
    public static var liveValue: VpnApiClient = {
        @Dependency(\.networking) var networking
        @Dependency(\.serverRepository) var serverRepository
        @Dependency(\.vpnKeychain) var vpnKeychain
        @Dependency(\.countryCodeProvider) var countryCodeProvider
        @Dependency(\.authKeychain) var authKeychain

        @Sendable
        func userLocation() async -> UserLocation? {
            do {
                return try await networking.perform(request: LocationRequest())
            } catch {
                log.error("Couldn't parse user's ip location response", category: .api, event: .response, metadata: ["error": "\(error)"])
                return nil
            }
        }

        @Sendable
        func clientConfig(
            for shortenedIp: String?,
            completion: @escaping (Result<ClientConfig, Error>) -> Void
        ) {
            let request = VPNClientConfigRequest(
                isAuth: vpnKeychain.userIsLoggedIn,
                ip: shortenedIp
            )

            networking.request(request) { (result: Result<JSONDictionary, Error>) in
                switch result {
                case let .success(response):
                    do {
                        let data = try JSONSerialization.data(withJSONObject: response as Any, options: [])
                        let decoder = JSONDecoder()
                        // this strategy is decapitalizing first letter of response's labels to get appropriate name
                        decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                        let clientConfigResponse = try decoder.decode(ClientConfigResponse.self, from: data)

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

        @Sendable
        func clientConfig(for shortenedIp: String?) async throws -> ClientConfig {
            try await withCheckedThrowingContinuation { continuation in
                clientConfig(for: shortenedIp, completion: continuation.resume(with:))
            }
        }

        @Sendable
        func clientCredentials() async throws -> VpnCredentials {
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
                    throw CommonVpnError.subuserWithoutSessions
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

        @Sendable
        func virtualServices() async throws -> VPNStreamingResponse {
            try await networking.perform(request: VPNStreamingRequest())
        }

        @Sendable
        func userInfo() async throws -> User {
            try await Authenticator(api: networking.apiService).getUserInfo()
        }

        @Sendable
        func userAddresses() async throws -> [Address] {
            try await Authenticator(api: networking.apiService).getAddresses()
        }

        // The following route is used to retrieve VPN server information, including scores for the best server to connect to depending on a user's proximity to a server and its load. To provide relevant scores even when connected to VPN, we send a truncated version of the user's public IP address. In keeping with our no-logs policy, this partial IP address is not stored on the server and is only used to fulfill this one-off API request.
        @Sendable
        func serverInfo(
            ip: TruncatedIp?,
            countryCode: String?,
            freeTier: Bool,
            completion: @escaping (Result<ServerInfoResponse, Error>) -> Void
        ) {
            let countryCodes: [String] = (countryCode.map { [$0] } ?? []) // country code from v1/locations response
                .appending(countryCodeProvider.countryCodes) // local guesses at appropriate country codes
                .uniqued

            let shouldSendLastModifiedValue = VPNFeatureFlagType.timestampedLogicals.enabled
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
                case let .success(.notModified(lastModified)):
                    log.debug("Logicals unchanged since last request", metadata: ["lastModified": "\(optional: lastModified)"])
                    result = .success(.notModified(since: lastModified))

                case let .success(.modified(lastModified, json)):
                    guard let serversJson = json.jsonArray(key: "LogicalServers") else {
                        log.error("'Servers' field not present in server info request's response", category: .api, event: .response)
                        let error = ParseError.serverParse
                        result = .failure(error)
                        return
                    }

                    guard !serversJson.isEmpty else {
                        // throw error to log the user out
                        result = .failure(CommonVpnError.noConnectionsAvailable)
                        return
                    }

                    var serverModels: [ServerModel] = []
                    for json in serversJson {
                        do {
                            try serverModels.append(ServerModel(dic: json))
                        } catch {
                            log.error("Failed to parse server info for json", category: .api, event: .response, metadata: ["error": "\(error)", "json": "\(json)"])
                        }
                    }
                    result = .success(.modified(at: lastModified, servers: serverModels, freeServersOnly: freeTier))

                case .failure:
                    result = .failure(CommonVpnError.logicalsEndpointFailed)
                }
            }
        }

        @Sendable
        func serverInfo(ip: TruncatedIp?, countryCode: String?, freeTier: Bool) async throws -> ServerInfoResponse {
            try await withCheckedThrowingContinuation { continuation in
                serverInfo(ip: ip, countryCode: countryCode, freeTier: freeTier, completion: continuation.resume(with:))
            }
        }

        return VpnApiClient(
            vpnProperties: { isDisconnected, lastKnownLocation, serversAccordingToTier in
                // Only retrieve IP address when not connected to VPN
                async let asyncLocation = (isDisconnected ? userLocation() : lastKnownLocation) ?? lastKnownLocation
                let clientConfig = try? await clientConfig(for: asyncLocation?.ip)
                let asyncCredentials = try await clientCredentials()

                return try await VpnProperties(
                    serverInfo: serverInfo(
                        ip: (asyncLocation?.ip).flatMap { TruncatedIp(ip: $0) },
                        countryCode: asyncLocation?.country,
                        freeTier: asyncCredentials.maxTier.isFreeTier && serversAccordingToTier
                    ),
                    streamingServices: try? virtualServices(),
                    vpnCredentials: asyncCredentials,
                    location: asyncLocation,
                    clientConfig: clientConfig,
                    user: try? userInfo(),
                    addresses: try? userAddresses()
                )
            },
            refreshServerInfo: { lastKnownIp, freeTier in
                let location = await userLocation()

                guard lastKnownIp == nil || location?.ip != lastKnownIp else {
                    return nil
                }

                let serverInfo = try await serverInfo(
                    ip: (location?.ip).flatMap { TruncatedIp(ip: $0) },
                    countryCode: location?.country,
                    freeTier: freeTier
                )

                return await (
                    serverInfo: serverInfo,
                    location: location,
                    streamingServices: try? virtualServices()
                )
            },
            clientCredentials: {
                try await clientCredentials()
            },
            serverInfo: { ip, countryCode, freeTier in
                try await serverInfo(ip: ip, countryCode: countryCode, freeTier: freeTier)
            },
            serverState: { id in
                func serverState(serverId id: String, completion: @escaping (Result<VpnServerState, Error>) -> Void) {
                    networking.request(VPNServerRequest(id)) { (result: Result<JSONDictionary, Error>) in
                        switch result {
                        case let .success(response):
                            guard let json = response.jsonDictionary(key: "Server"), let serverState = try? VpnServerState(dictionary: json) else {
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
                return try await withCheckedThrowingContinuation { continuation in
                    serverState(serverId: id, completion: continuation.resume(with:))
                }
            },
            userLocation: {
                await userLocation()
            },
            sessionsCount: {
                try await networking.perform(request: VPNSessionsCountRequest())
            },
            loads: { lastKnownIp in
                func loads(lastKnownIp: TruncatedIp?, completion: @escaping (Result<ContinuousServerPropertiesDictionary, Error>) -> Void) {
                    networking.request(VPNLoadsRequest(truncatedIP: lastKnownIp)) { (result: Result<JSONDictionary, Error>) in
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
                return try await withCheckedThrowingContinuation { continuation in
                    loads(lastKnownIp: lastKnownIp, completion: continuation.resume(with:))
                }
            },
            clientConfig: { shortenedIp in
                try await clientConfig(for: shortenedIp)
            },
            virtualServices: {
                try await virtualServices()
            },
            userInfo: {
                try await userInfo()
            },
            userAddresses: {
                try await userAddresses()
            }
        )
    }()
}

public extension DependencyValues {
    var vpnApiClient: VpnApiClient {
        get { self[VpnApiClientKey.self] }
        set { self[VpnApiClientKey.self] = newValue }
    }
}
