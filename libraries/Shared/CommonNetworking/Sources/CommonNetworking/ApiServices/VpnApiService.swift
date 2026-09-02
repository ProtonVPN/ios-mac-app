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

import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import Persistence
import ProtonCoreAuthentication
import ProtonCoreDataModel
import VPNAppCore
import VPNShared

@DependencyClient
public struct VpnApiClient: Sendable {
    public internal(set) var vpnProperties: @Sendable (_ isDisconnected: Bool, _ lastKnownLocation: UserLocation?, _ serversAccordingToTier: Bool) async throws -> VpnProperties
    public internal(set) var clientCredentials: @Sendable () async throws -> VpnCredentials
    public internal(set) var serverInfo: @Sendable (_ ip: TruncatedIp?, _ countryCode: String?, _ scope: ServerListScope) async throws -> ServerInfoResponse
    public internal(set) var serverState: @Sendable (_ serverId: String) async throws -> VpnServerState
    public internal(set) var sessionsCount: @Sendable () async throws -> SessionsResponse
    public internal(set) var loads: @Sendable (_ lastKnownIp: TruncatedIp?) async throws -> ContinuousServerPropertiesDictionary
    public internal(set) var clientConfig: @Sendable (_ for: String?) async throws -> ClientConfig
    public internal(set) var virtualServices: @Sendable () async throws -> VPNStreamingResponse
    public internal(set) var userInfo: @Sendable () async throws -> User
    public internal(set) var userAddresses: @Sendable () async throws -> [Address]
}

enum VpnApiClientKey: DependencyKey {
    static var liveValue: VpnApiClient = {
        @Dependency(\.networking) var networking
        @Dependency(\.serverRepository) var serverRepository
        @Dependency(\.credentialsProvider) var credentialsProvider
        @Dependency(\.countryCodeProvider) var countryCodeProvider
        @Dependency(\.authKeychain) var authKeychain

        @Sendable
        func clientConfig(
            for shortenedIp: String?,
            completion: @escaping (Result<ClientConfig, Error>) -> Void
        ) {
            let request = VPNClientConfigRequest(
                isAuth: credentialsProvider.hasCredentials,
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
            scope requestedScope: ServerListScope,
            completion: @escaping (Result<ServerInfoResponse, Error>) -> Void
        ) {
            let countryCodes: [String] = (countryCode.map { [$0] } ?? []) // country code from v1/locations response
                .appending(countryCodeProvider.countryCodes) // local guesses at appropriate country codes
                .uniqued

            // The write side of this contract lives in `ServerListUpdater`
            @Dependency(\.appLanguage) var appLanguage
            let requestLanguage = appLanguage()
            let scope = serverRepository.logicalsRequestScope(for: requestedScope, language: requestLanguage)
            let lastModified = serverRepository.logicalsRequestBaseline(scope: scope, language: requestLanguage)

            networking.request(
                LogicalsRequest(
                    ip: ip,
                    countryCodes: countryCodes,
                    freeTier: scope.isCappedAtFreeTier,
                    lastModified: lastModified
                )
            ) { (response: Result<IfModifiedSinceResponse<LogicalsResponse>, Error>) in
                let result: Result<ServerInfoResponse, Error>
                defer { completion(result) }

                switch response {
                case let .success(.notModified(lastModified)):
                    log.debug("Logicals unchanged since last request", metadata: ["lastModified": "\(optional: lastModified)"])
                    result = .success(.notModified(since: lastModified, scope: scope))

                case let .success(.modified(lastModified, logicals)):
                    switch logicals {
                    case let .servers(servers):
                        result = .success(.modified(
                            at: lastModified,
                            servers: servers.map(\.vpnServer),
                            scope: scope,
                            language: requestLanguage
                        ))

                    case let .unreadable(receivedServerCount):
                        // The response is unreadable (and not the account losing its servers), so
                        // report a parse failure. That leaves the caller with the servers it already
                        // stored, where `noConnectionsAvailable` would log every user out over a
                        // decoding regression.
                        log.error(
                            "Discarded every server in the logicals response",
                            category: .api,
                            event: .response,
                            metadata: ["receivedServerCount": "\(receivedServerCount)"]
                        )
                        result = .failure(ParseError.serverParse)

                    case .empty:
                        // The account has no server to connect to. Throw so the caller logs the user out.
                        result = .failure(CommonVpnError.noConnectionsAvailable)
                    }

                case let .failure(error):
                    log.error(
                        "Failed to read the logicals response",
                        category: .api,
                        event: .response,
                        metadata: ["error": "\(error)"]
                    )
                    result = .failure(CommonVpnError.logicalsEndpointFailed)
                }
            }
        }

        @Sendable
        func serverInfo(ip: TruncatedIp?, countryCode: String?, scope: ServerListScope) async throws -> ServerInfoResponse {
            try await withCheckedThrowingContinuation { continuation in
                serverInfo(ip: ip, countryCode: countryCode, scope: scope, completion: continuation.resume(with:))
            }
        }

        return VpnApiClient(
            vpnProperties: { isDisconnected, lastKnownLocation, serversAccordingToTier in
                // The endpoint is only asked while no tunnel is up: through one it answers with the
                // exit address rather than the user's own. A failed request leaves this nil too — the
                // caller can't tell the two apart, and in both cases nothing new was measured.
                async let asyncMeasuredLocation: UserLocation? = isDisconnected
                    ? try? networking.perform(request: LocationRequest())
                    : nil
                let measuredLocation = await asyncMeasuredLocation
                // Whatever the caller already knew stands in for scoring when nothing was measured.
                let location = measuredLocation ?? lastKnownLocation
                let clientConfig = try? await clientConfig(for: location?.ip)
                let asyncCredentials = try await clientCredentials()

                let scope: ServerListScope = if authKeychain.usernameCachedOrFetched == nil {
                    .guestSession
                } else if asyncCredentials.maxTier.isFree, serversAccordingToTier {
                    .freeTier
                } else {
                    .allTiers
                }

                return try await VpnProperties(
                    serverInfo: serverInfo(
                        ip: (location?.ip).flatMap { TruncatedIp(ip: $0) },
                        countryCode: location?.country,
                        scope: scope
                    ),
                    streamingServices: try? virtualServices(),
                    vpnCredentials: asyncCredentials,
                    location: location,
                    measuredLocation: measuredLocation,
                    clientConfig: clientConfig,
                    user: try? userInfo(),
                    addresses: try? userAddresses()
                )
            },
            clientCredentials: {
                try await clientCredentials()
            },
            serverInfo: { ip, countryCode, scope in
                try await serverInfo(ip: ip, countryCode: countryCode, scope: scope)
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
