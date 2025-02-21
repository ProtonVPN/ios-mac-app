//
//  Created on 18/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

// TODO: Clean up imports
import Foundation
import enum NetworkExtension.NEVPNStatus

import Clocks
import ComposableArchitecture
import Dependencies

import Domain
import CoreConnection
import CertificateAuthentication
import ExtensionManager
import LocalAgent
import VPNAppCore

@available(iOS 16, *)
public struct ConnectionFeature: Reducer, Sendable {
    @Dependency(\.smartPortSelector) private var portSelector
    @Dependency(\.serverSelector) private var serverSelector
    @Dependency(\.connectionIntentStorage) private var storage
    @Dependency(\.connectionBridge) private var connectionBridge
    @Dependency(\.vpnFeaturesProvider) private var vpnFeaturesProvider
    @Dependency(\.connectionIntentStorage) private var intentStorage

    public init() { }

    public struct State: Equatable, Sendable {
        public var connectionState: ConnectionState // TODO: Remember to write to @Shared(\.connectionState)
        public internal(set) var currentIntent: ServerConnectionIntent?
        public internal(set) var queuedIntent: ConnectionPreparationIntent?
        internal var shouldRegisterServerChangeOnConnection: Bool = false
        internal var internalState: InternalConnectionFeature.State // Explicitly as internal as it gets

        public init(
            connectionState: ConnectionState = .resolving,
            internalState: InternalConnectionFeature.State = .init()
        ) {
            self.connectionState = connectionState
            self.internalState = internalState
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case prepare(ConnectionPreparationIntent)
        case startConnection(ServerConnectionIntent)
        case internalAction(InternalConnectionFeature.Action)
        case input(Input)
        case delegate(Delegate)

        public enum Input: Sendable {
            case onLaunch
            case onLogout
            case connect(ConnectionPreparationIntent)
            case applySettings(Set<ConnectionFeatureChange.AgentFeature>)
            case disconnect
        }

        public enum Delegate: Sendable {
            case stateChanged(ConnectionState)
            case connectionFailed(ConnectionError)
        }
    }

    private enum CancelID {
        case preparation
        case connectionTimeout
        case observation
    }

    public var body: some Reducer<State, Action> {
        // Firstly, process internal connection events
        // TODO: Do we receive the delegate action (state change) event before other effect are processed?
        Scope(state: \.internalState, action: \.internalAction) { InternalConnectionFeature() }
        Reduce { state, action in
            switch action {
            case .input(.onLaunch):
                return .merge(
                    .send(.internalAction(.startObserving)),
                    .listen(to: connectionBridge.intentStream()) { .input($0) } // reinject intents from bridge into this feature
                ).cancellable(id: CancelID.observation, cancelInFlight: true)

            case .input(.connect(let intent)):
                switch state.internalConnectionState {
                case .disconnecting:
                    // Save the reconnection intent for once the disconnection process is finished
                    state.queuedIntent = intent
                    return .none

                case .connecting, .connected:
                    state.queuedIntent = intent
                    return .send(.internalAction(.disconnect(.userIntent))) // TODO: remove disconnect params except maybe error

                case .disconnected:
                    return .send(.prepare(intent))

                case .unknown:
                    assertionFailure("Connect intent received before feature was ready")
                    return .none
                }

            case .input(.applySettings(let agentFeatures)):
                return .send(.internalAction(.localAgent(.setFeatures(agentFeatures))))

            case .input(.disconnect):
                return .send(.internalAction(.disconnect(.userIntent)))

            case .input(.onLogout):
                return .send(.internalAction(.handleLogout))

            case .prepare(let intent):
                // protocol and port selection is only sensible while the tunnel is disconnected
                assert(state.internalConnectionState.is(\.disconnected))
                state.shouldRegisterServerChangeOnConnection = intent.spec.location == .random

                return .run { send in
                    // TODO: make sure it's the correct protocol
                    let portSelectionResult = try await portSelector.select(intent.server.endpoint, .vpnProtocol(.wireGuard(.udp)))
                    try Task.checkCancellation()

                    guard case .wireGuard(let transport) = portSelectionResult.chosenProtocol else {
                        throw ConnectionError.unexpectedProtocol(portSelectionResult.chosenProtocol)
                    }

                    let ports = portSelectionResult.ports
                    log.info("WG transport and ports selected", category: .connection, metadata: ["transport": "\(transport)", "port": "\(ports)"])

                    let features = vpnFeaturesProvider.connectionFeatures()
                    let tunnelFeatures = vpnFeaturesProvider.tunnelFeatures()
                    let tunnelSettings = TunnelSettings(transport: .udp, ports: ports, features: tunnelFeatures)

                    let intent = ServerConnectionIntent(
                        spec: intent.spec,
                        server: intent.server,
                        tunnelSettings: tunnelSettings,
                        features: features
                    )

                    try storage.set(intent)
                    await send(.startConnection(intent))

                } catch: { error, send in
                    log.error("Failed in preparing connection with error: \(error)")
                    switch error {
                    case let connectionError as ConnectionError:
                        await send(.internalAction(.disconnect(.connectionFailure(connectionError))))
                    default:
                        let wrappedError = ConnectionError.WrappedError(wrapped: error)
                        await send(.internalAction(.disconnect(.connectionFailure(.preparation(wrappedError)))))
                    }
                }.cancellable(id: CancelID.preparation, cancelInFlight: true)

            case .startConnection(let intent):
                state.currentIntent = intent
                return .send(.internalAction(.connect(intent)))

            case .internalAction(.delegate(.stateChanged(let oldState, .disconnected(.some(let error))))):
                return .concatenate(
                    .send(.delegate(.stateChanged(.disconnected))),
                    .send(.delegate(.connectionFailed(error)))
                )

            case .internalAction(.delegate(.stateChanged(let oldState, .disconnected(nil)))):
                if let reconnectionIntent = state.queuedIntent {
                    // assert(state.connectionState.is(\.connecting))
                    log.info("Disconnected, proceeding with reconnection to \(reconnectionIntent.server)")
                    state.queuedIntent = nil
                    return .send(.prepare(reconnectionIntent))
                } else {
                    return .send(.delegate(.stateChanged(.disconnected)))
                }

            case .internalAction(.delegate(.stateChanged(let oldState, .connected(let server, let connectedAt, let details)))):
                if state.shouldRegisterServerChangeOnConnection {
                    @Dependency(\.serverChangeAuthorizer) var authorizer
                    authorizer.registerServerChange(connectedAt: connectedAt)
                }
                return .run { [state] send in
                    let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
                    return await send(.delegate(.stateChanged(.connected(intent, server, connectedAt, details))))
                } catch: { error, send in
                    return await send(.internalAction(.disconnect(.connectionFailure(.intentMissing))))
                }

            case .internalAction(.delegate(.stateChanged(let oldState, .connecting(let server)))):
                if oldState.is(\.unknown) {
                    log.info("Ignoring state transition to connecting since we are resolving from unknown")
                    return .none
                }
                return .run { [state] send in
                    let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
                    let resolvedIntent = ConnectionPreparationIntent(spec: intent.spec, server: intent.server)
                    return await send(.delegate(.stateChanged(.connecting(resolvedIntent, server ?? intent.server))))
                } catch: { error, send in
                    return await send(.internalAction(.disconnect(.connectionFailure(.intentMissing))))
                }

            case .internalAction(.delegate(.stateChanged(let oldState, .disconnecting))):
                return .run { [state] send in
                    let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
                    if let reconnectionIntent = state.queuedIntent {
                        return await send(.delegate(.stateChanged(.connecting(reconnectionIntent, reconnectionIntent.server))))
                    } else if case .connected(let server, _, _) = oldState {
                        // try to get spec and server from `oldState`
                        return await send(.delegate(.stateChanged(.disconnecting(intent, server))))
                    } else if case .connecting(let server) = oldState {
                        return await send(.delegate(.stateChanged(.disconnecting(intent, server ?? intent.server))))
                    } else {
                        // skip state update
                        log.error("Unexpected transition to disconnecting from \(oldState)")
                    }
                } catch: { error, send in
                    return await send(.internalAction(.disconnect(.connectionFailure(.intentMissing))))
                }

            case .internalAction(.delegate(.stateChanged(let oldState, .unknown))):
                return .send(.delegate(.stateChanged(.resolving)))

            case .internalAction:
                return .none

            case .delegate(.stateChanged):
                // It's up to the parent feature to modify any shared state.
                return .none

            case .delegate(.connectionFailed):
                // It's up to the parent feature to react to connection failure.
                return .none
            }
        }
    }
}

extension ConnectionFeature.State {
    var internalConnectionState: InternalConnectionState {
        return InternalConnectionState(connectionFeatureState: internalState)
    }
}

// User-facing connection state
@CasePathable
public enum ConnectionState: Equatable, Sendable {
    case resolving
    case disconnected
    case disconnecting(ServerConnectionIntent, Server)
    case connecting(ConnectionPreparationIntent, Server)
    case connected(ServerConnectionIntent, Server, Date, ConnectionDetailsMessage?)
}
