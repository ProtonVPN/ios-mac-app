//
//  Created on 28/05/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import enum NetworkExtension.NEVPNStatus

import Clocks
import ComposableArchitecture
import Dependencies

import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import struct Domain.ServerConnectionIntent
import ConnectionFoundations
import CertificateAuthentication
import ExtensionManager
import LocalAgent

public struct ConnectionFeature: Reducer, Sendable {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.serverIdentifier) var serverIdentifier

    private static let defaultConnectionTimeout = Duration.seconds(30)

    public init() { }

    public struct State: Equatable, Sendable {
        public var tunnel: ExtensionFeature.State
        public var localAgent: LocalAgentFeature.State
        public var certAuth: CertificateAuthenticationFeature.State
        var serverReconnectionIntent: ServerConnectionIntent?

        public init(
            tunnelState: ExtensionFeature.State = .disconnected(nil),
            certAuthState: CertificateAuthenticationFeature.State = .idle,
            localAgentState: LocalAgentFeature.State = .disconnected(nil)
        ) {
            self.tunnel = tunnelState
            self.certAuth = certAuthState
            self.localAgent = localAgentState
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case connect(ServerConnectionIntent)
        case disconnect(DisconnectReason)
        case tunnel(ExtensionFeature.Action)
        case certAuth(CertificateAuthenticationFeature.Action)
        case localAgent(LocalAgentFeature.Action)
        case clearErrors
        case startObserving
        case stopObserving
    }

    @CasePathable
    public enum DisconnectReason: Equatable, Sendable {
        case reconnection(ServerConnectionIntent)
        case connectionFailure(ConnectionError)
        case userIntent
    }

    private enum CancelID { case connectionTimeout }

    public var body: some Reducer<State, Action> {
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() }
        Scope(state: \.certAuth, action: \.certAuth) { CertificateAuthenticationFeature() }
        Scope(state: \.localAgent, action: \.localAgent) { LocalAgentFeature() }
        Reduce { state, action in
            switch action {
            case .startObserving:
                return .merge(
                    .send(.tunnel(.startObservingStateChanges)),
                    .send(.localAgent(.startObservingEvents))
                )
            case .stopObserving:
                return .merge(
                    .send(.tunnel(.stopObservingStateChanges)),
                    .send(.localAgent(.stopObservingEvents))
                )
            case .connect(let intent):
                clearErrorsFromPreviousAttempts(state: &state)

                return .run { send in
                    await send(.tunnel(.connect(intent)))
                    try await clock.sleep(for: Self.defaultConnectionTimeout)
                    try Task.checkCancellation()
                    await send(.disconnect(.connectionFailure(.timeout)))
                } catch: { error, _ in
                    log.info("Timeout task cancellation error: \(error)")
                }.cancellable(id: CancelID.connectionTimeout)

            case .disconnect(let reason):
                if case let .reconnection(intent) = reason {
                    state.serverReconnectionIntent = intent
                }
                return .merge(
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.localAgent(.disconnect(nil))),
                    .send(.tunnel(.disconnect))
                )

            case .tunnel(.connectionFinished(.success)):
                return .send(.certAuth(.loadAuthenticationData))

            case .certAuth(.loadingFinished(.success(let authData))):
                guard case .connected(let logicalInfo) = state.tunnel else {
                    log.error("Finished loading auth data but tunnel is not connected")
                    return .none
                }
                guard let server = serverIdentifier.fullServerInfo(logicalInfo) else {
                    log.error("Detected connection to unknown server, disconnecting", category: .connection)
                    return .send(.disconnect(.connectionFailure(.serverMissing)))
                }
                let data = VPNAuthenticationData(clientKey: authData.keys.privateKey, clientCertificate: authData.certificate.certificate)
                return .send(.localAgent(.connect(server.endpoint, data)))

            case .certAuth(.loadingFinished(.failure(let error))):
                log.error("Failed to load authentication data: \(error)")
                return .send(.disconnect(.connectionFailure(.certAuth(.unexpected(error)))))

            case .tunnel(.tunnelStatusChanged(.disconnected)):
                guard case .disconnected = state.localAgent,
                      let intent = state.serverReconnectionIntent else { return .none }
                state.serverReconnectionIntent = nil
                return .send(.connect(intent))

            case .localAgent(.event(.state(.disconnected))):
                guard case .disconnected = state.tunnel,
                      let intent = state.serverReconnectionIntent else { return .none }
                state.serverReconnectionIntent = nil
                return .send(.connect(intent))

            case .localAgent(.event(.state(.connected))):
                return .cancel(id: CancelID.connectionTimeout)

            case .localAgent(.delegate(.errorReceived(let error))):
                switch error.resolutionStrategy {
                case .none:
                    return .none

                case .disconnect:
                    return .merge(
                        .send(.localAgent(.disconnect(.agentError(error)))),
                        .send(.tunnel(.disconnect))
                    )

                case .reconnect(.withNewKeysAndCertificate):
                    return .concatenate(
                        .send(.localAgent(.disconnect(nil))),
                        .send(.certAuth(.regenerateKeys)),
                        .send(.certAuth(.loadAuthenticationData))
                    )

                case .reconnect(.withNewCertificate):
                    return .concatenate(
                        .send(.localAgent(.disconnect(nil))),
                        .send(.certAuth(.purgeCertificate)), // In case it's not just expired
                        .send(.certAuth(.loadAuthenticationData))
                    )

                case .reconnect(.withExistingCertificate):
                    return .concatenate(
                        .send(.localAgent(.disconnect(nil))),
                        .send(.certAuth(.loadAuthenticationData))
                    )
                }

            case .tunnel:
                return .none

            case .localAgent:
                return .none

            case .certAuth:
                return .none

            case .clearErrors:
                if case .failed = state.certAuth{
                    state.certAuth = .idle
                }
                if case let .disconnected(error) = state.tunnel, error != nil {
                    state.tunnel = .disconnected(nil)
                }
                if case let .disconnected(error) = state.localAgent, error != nil {
                    state.localAgent = .disconnected(nil)
                }
                return .none
            }
        }
    }

    private func clearErrorsFromPreviousAttempts(state: inout State) {
        if case .disconnected(let tunnelError) = state.tunnel, let tunnelError {
            log.info("Resetting tunnel connection error from previous connection attempt: \(tunnelError)")
            state.tunnel = .disconnected(nil)
        }
        if case .failed(let certAuthError) = state.certAuth {
            log.info("Resetting cert auth error from previous connection attempt: \(certAuthError)")
            state.certAuth = .idle
        }
        if case .disconnected(let agentError) = state.localAgent, let agentError {
            log.info("Resetting local agent connection error from previous connection attempt: \(agentError)")
            state.localAgent = .disconnected(nil)
        }
    }
}

@CasePathable
public enum ConnectionError: Error, Equatable, Sendable {
    case certAuth(CertificateAuthenticationError)
    case tunnel(TunnelConnectionError)
    case agent(LocalAgentConnectionError)
    case serverMissing
    case timeout
}
