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

import Foundation

import Clocks
import ComposableArchitecture
import Dependencies

import Domain
import CoreConnection
import LocalAgent
import VPNAppCore

@available(iOS 16, *)
public struct ConnectionFeature: Reducer, Sendable {
    @Dependency(\.connectionBridge) private var connectionBridge
    @Dependency(\.connectionIntentStorage) private var intentStorage
    @Dependency(\.connectionIntentResolver) private var intentResolver

    public init() { }

    public struct State: Equatable, Sendable {
        public var connectionState: ConnectionState
        public internal(set) var currentIntent: ServerConnectionIntent?
        public internal(set) var queuedIntent: ConnectionPreparationIntent?
        internal var shouldRegisterServerChangeOnConnection: Bool
        internal var core: CoreConnectionFeature.State

        public init(
            connectionState: ConnectionState = .resolving,
            currentIntent: ServerConnectionIntent? = nil,
            queuedIntent: ConnectionPreparationIntent? = nil,
            shouldRegisterServerChangeOnConnection: Bool = false,
            core: CoreConnectionFeature.State = .init()
        ) {
            self.connectionState = connectionState
            self.currentIntent = currentIntent
            self.queuedIntent = queuedIntent
            self.shouldRegisterServerChangeOnConnection = shouldRegisterServerChangeOnConnection
            self.core = core
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case prepare(ConnectionPreparationIntent)
        case startConnection(ServerConnectionIntent)
        case core(CoreConnectionFeature.Action)
        case input(Input)
        case delegate(Delegate)
        case stopObserving

        @CasePathable
        public enum Input: Sendable {
            case onLaunch
            case onLogout
            case connect(ConnectionPreparationIntent)
            case applySettings(Set<ConnectionFeatureChange.AgentFeature>)
            case disconnect
        }

        @CasePathable
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
        Scope(state: \.core, action: \.core) { CoreConnectionFeature() } // Firstly, process internal connection events
        Reduce { state, action in
            switch action {
            case .input(.onLaunch):
                return .merge(
                    .send(.core(.startObserving)),
                    .listen(to: connectionBridge.intentStream()) { .input($0) } // reinject intents from bridge into this feature
                ).cancellable(id: CancelID.observation, cancelInFlight: true)

            case .stopObserving:
                return .merge(.send(.core(.stopObserving)), .cancel(id: CancelID.observation))

            case .input(.connect(let intent)):
                switch state.coreConnectionState {
                case .disconnecting:
                    // Save the reconnection intent for once the disconnection process is finished
                    state.queuedIntent = intent
                    return .none

                case .starting, .connecting, .connected:
                    state.queuedIntent = intent
                    return .send(.core(.disconnect(.userIntent)))

                case .disconnected:
                    return .send(.prepare(intent))

                case .unknown:
                    // TODO: return connection failed with appropriate error
                    return .none
                }

            case .input(.applySettings(let agentFeatures)):
                return .send(.core(.localAgent(.setFeatures(agentFeatures))))

            case .input(.disconnect):
                return .send(.core(.disconnect(.userIntent)))

            case .input(.onLogout):
                return .merge(.send(.stopObserving), .send(.core(.handleLogout)))

            case .prepare(let intent):
                // protocol and port selection is only sensible while the tunnel is disconnected
                assert(state.coreConnectionState.is(\.disconnected))
                state.shouldRegisterServerChangeOnConnection = intent.spec.location == .random

                return .run { send in
                    let resolvedIntent = try await intentResolver.resolve(intent)
                    try intentStorage.set(resolvedIntent)
                    await send(.startConnection(resolvedIntent))
                } catch: { error, send in
                    log.error("Failed in preparing connection with error: \(error)")
                    switch error {
                    case let connectionError as ConnectionError:
                        await send(.core(.disconnect(.connectionFailure(connectionError))))
                    default:
                        let wrappedError = ConnectionError.WrappedError(wrapped: error)
                        await send(.core(.disconnect(.connectionFailure(.preparation(wrappedError)))))
                    }
                }.cancellable(id: CancelID.preparation, cancelInFlight: true)

            case .startConnection(let intent):
                state.currentIntent = intent
                return .send(.core(.connect(intent)))

            case .core(.delegate(.stateChanged(let oldState, .disconnected(.some(let error))))):
                return .concatenate(
                    .send(.delegate(.stateChanged(.disconnected))),
                    .send(.delegate(.connectionFailed(error)))
                )

            case .core(.delegate(.stateChanged(let oldState, .disconnected(nil)))):
                if let reconnectionIntent = state.queuedIntent {
                    // assert(state.connectionState.is(\.connecting))
                    log.info("Disconnected, proceeding with reconnection to \(reconnectionIntent.server)")
                    state.queuedIntent = nil
                    return .send(.prepare(reconnectionIntent))
                } else {
                    return .send(.delegate(.stateChanged(.disconnected)))
                }

            case .core(.delegate(.stateChanged(let oldState, .connected(let server, let connectedAt, let details)))):
                if state.shouldRegisterServerChangeOnConnection {
                    @Dependency(\.serverChangeAuthorizer) var authorizer
                    authorizer.registerServerChange(connectedAt: connectedAt)
                }
                return .run { [state] send in
                    let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
                    return await send(.delegate(.stateChanged(.connected(intent, intent.server, connectedAt, details))))
                } catch: { error, send in
                    return await send(.core(.disconnect(.connectionFailure(.intentMissing))))
                }

            case .core(.delegate(.stateChanged(let oldState, .starting))): // (let server)))):
                if oldState.is(\.unknown) {
                    log.info("Ignoring state transition to connecting since we are resolving from unknown")
                    return .none
                }
                return .run { [state] send in
                    let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
                    let resolvedIntent = ConnectionPreparationIntent(spec: intent.spec, server: intent.server)
                    return await send(.delegate(.stateChanged(.connecting(resolvedIntent, intent.server))))
                } catch: { error, send in
                    return await send(.core(.disconnect(.connectionFailure(.intentMissing))))
                }

            case .core(.delegate(.stateChanged(let oldState, .disconnecting))):
                return .run { [state] send in
                    let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
                    if let reconnectionIntent = state.queuedIntent {
                        return await send(.delegate(.stateChanged(.connecting(reconnectionIntent, reconnectionIntent.server))))
                    } else if case .connected(let server, _, _) = oldState {
                        // try to get spec and server from `oldState`
                        return await send(.delegate(.stateChanged(.disconnecting(intent, intent.server))))
                    } else if case .starting = oldState {
                        return await send(.delegate(.stateChanged(.disconnecting(intent, intent.server))))
                    } else {
                        // skip state update
                        log.error("Unexpected transition to disconnecting from \(oldState)")
                    }
                } catch: { error, send in
                    return await send(.core(.disconnect(.connectionFailure(.intentMissing))))
                }

            case .core(.delegate(.stateChanged(let oldState, .unknown))):
                return .send(.delegate(.stateChanged(.resolving)))

            case .core:
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
    var coreConnectionState: CoreConnectionState {
        return CoreConnectionState(connectionFeatureState: core)
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
