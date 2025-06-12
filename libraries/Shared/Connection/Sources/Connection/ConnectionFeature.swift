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

import CoreConnection
import Domain
import LocalAgent
import VPNAppCore

@available(iOS 16, *)
public struct ConnectionFeature: Reducer, Sendable {
    @Dependency(\.connectionBridge) private var connectionBridge
    @Dependency(\.connectionIntentStorage) private var intentStorage
    @Dependency(\.connectionIntentResolver) private var intentResolver

    public init() {}

    public struct State: Equatable, Sendable {
        @SharedReader(.userTier) public var userTier: Int?
        public internal(set) var currentIntent: ServerConnectionIntent?
        public internal(set) var reconnectionIntent: ConnectionPreparationIntent?
        var connectionState: ConnectionState
        var shouldRegisterServerChangeOnConnection: Bool
        var core: CoreConnectionFeature.State

        package init(
            currentIntent: ServerConnectionIntent?,
            queuedIntent: ConnectionPreparationIntent?,
            connectionState: ConnectionState,
            shouldRegisterServerChangeOnConnection: Bool,
            core: CoreConnectionFeature.State
        ) {
            self.currentIntent = currentIntent
            self.reconnectionIntent = queuedIntent
            self.connectionState = connectionState
            self.shouldRegisterServerChangeOnConnection = shouldRegisterServerChangeOnConnection
            self.core = core
        }
    }

    @CasePathable
    @dynamicMemberLookup
    public enum Action: Sendable {
        case prepare(ConnectionPreparationIntent)
        case finishedPreparing(Result<ServerConnectionIntent, Error>)
        case core(CoreConnectionFeature.Action)
        case input(Input)
        case delegate(Delegate)
        case stopObserving

        /// A subset of this reducer's actions suitable to be sent from outside
        @CasePathable
        public enum Input: Sendable {
            case onLaunch
            case onLogout
            case connect(ConnectionPreparationIntent)
            case applySettings(Set<ConnectionFeatureChange.AgentFeature>)
            case disconnect
        }

        /// A subset of this reducer's actions that must be handled appropriately by its parent
        @CasePathable
        @dynamicMemberLookup
        public enum Delegate: Sendable {
            case stateChanged(ConnectionState)
            case connectionFailed(ConnectionError)
            case intentResolutionFailed(ConnectionPreparationIntent, with: ConnectionIntentResolutionError)
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

            case let .input(.connect(intent)):
                do throws(ConnectionIntentResolutionError) {
                    try intentResolver.authorize(intent, state.userTier ?? .freeTier)
                } catch {
                    return .send(.delegate(.intentResolutionFailed(intent, with: error)))
                }

                switch state.coreConnectionState {
                case .unknown:
                    // We're not ready to accept a connection request yet
                    log.assertionFailure("Received a connection request before internal state was resolved")
                    return .none

                case .disconnecting:
                    // Save the reconnection intent for once the disconnection process is finished
                    state.reconnectionIntent = intent
                    // Disconnection could take some time (updating tunnel managers)
                    // Let's override user-facing state from disconnecting straight to connecting instead of waiting
                    let maskedConnectionState = ConnectionState.connecting(.unresolved(intent))
                    return updateStateSendingEffectIfNecessary(&state, to: maskedConnectionState)

                case .starting, .connecting, .connected:
                    state.reconnectionIntent = intent
                    return .send(.core(.disconnect(.userIntent)))

                case .disconnected:
                    return .send(.prepare(intent))
                }

            case let .input(.applySettings(agentFeatures)):
                if !state.coreConnectionState.is(\.connected) {
                    log.warning("Setting connection features while not connected", category: .connection)
                }
                return .concatenate(
                    .send(.core(.localAgent(.setFeatures(agentFeatures)))),
                    .send(.core(.certAuth(.refreshCertificate)))
                )

            case .input(.disconnect):
                return handleUserDisconnectionRequest(&state)

            case .input(.onLogout):
                return .merge(.send(.stopObserving), .send(.core(.handleLogout)))

            case let .prepare(intent):
                // protocol and port selection is only sensible while the tunnel is disconnected
                assert(state.coreConnectionState, is: \.disconnected)
                state.shouldRegisterServerChangeOnConnection = intent.spec.location == .random
                return .concatenate(
                    updateStateSendingEffectIfNecessary(&state, to: .connecting(.unresolved(intent))),
                    .run { send in
                        let result = await Result { try await intentResolver.resolve(intent) }
                        return await send(.finishedPreparing(result))
                    }.cancellable(id: CancelID.preparation, cancelInFlight: true)
                )

            case let .finishedPreparing(.success(resolvedIntent)):
                guard state.coreConnectionState.is(\.disconnected) else {
                    // Preparation can only be initiated while we are fully disconnected. If upon finishing preparation
                    // we are not disconnected, the tunnel was started externally. Let's disconnect with an error
                    log.error("Core connection state not disconnected after preparation", category: .connection)
                    return .send(.core(.disconnect(.connectionFailure(.preparation(.featureNotReady)))))
                }
                state.currentIntent = resolvedIntent
                do {
                    try intentStorage.set(resolvedIntent)
                    return .concatenate(
                        updateStateSendingEffectIfNecessary(&state, to: .connecting(.resolved(resolvedIntent, resolvedIntent.server))),
                        .send(.core(.connect(resolvedIntent)))
                    )
                } catch {
                    return .concatenate(
                        updateStateSendingEffectIfNecessary(&state, to: .disconnected),
                        .send(.delegate(.connectionFailed(.preparation(.wrapped(.init(wrapped: error))))))
                    )
                }

            case let .finishedPreparing(.failure(error)):
                log.error("Failed to preparing connection with error: \(error)")
                let wrappedError = ConnectionError.WrappedError(wrapped: error)
                return .concatenate(
                    updateStateSendingEffectIfNecessary(&state, to: .disconnected),
                    .send(.delegate(.connectionFailed(.preparation(.wrapped(wrappedError)))))
                )

            case let .core(.delegate(.stateChanged(_, .disconnected(.some(error))))):
                return .concatenate(
                    updateStateSendingEffectIfNecessary(&state, to: .disconnected),
                    .send(.delegate(.connectionFailed(error)))
                )

            case .core(.delegate(.stateChanged(_, .disconnected(nil)))):
                if let reconnectionIntent = state.reconnectionIntent {
                    assert(state.connectionState, is: \.connecting)
                    log.info("Disconnected, proceeding with reconnection to \(reconnectionIntent.server)")
                    state.reconnectionIntent = nil
                    return .send(.prepare(reconnectionIntent))
                } else {
                    return .concatenate(
                        updateStateSendingEffectIfNecessary(&state, to: .disconnected),
                        .send(.delegate(.stateChanged(.disconnected)))
                    )
                }

            case let .core(.delegate(.stateChanged(_, .connected(_, connectedAt, details)))):
                if state.shouldRegisterServerChangeOnConnection {
                    @Dependency(\.serverChangeAuthorizer) var authorizer
                    authorizer.registerServerChange(connectedAt: connectedAt)
                }
                return updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    .connected(intent, intent.server, connectedAt, details)
                }

            case let .core(.delegate(.stateChanged(oldState, .starting))):
                if oldState.is(\.unknown) {
                    // Since the previous state is unknown, we're figuring out the actual connection state at app startup.
                    // Let's skip the `connecting` while we continue to determine whether we're connected
                    log.debug("Ignoring state transition to starting since we are resolving from unknown", category: .connection)
                    return .none
                }
                return updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    .connecting(.resolved(intent, intent.server))
                }

            case .core(.delegate(.stateChanged(_, .connecting))):
                if state.connectionState.is(\.resolving) {
                    // Since the user facing state has not yet been resolved, let's skip the `connecting` state
                    log.debug("Ignoring state transition to connecting since we are resolving from unknown", category: .connection)
                    return .none
                }
                return updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    .connecting(.resolved(intent, intent.server))
                }

            case let .core(.delegate(.stateChanged(oldState, .disconnecting))):
                let queuedIntent = state.reconnectionIntent
                return updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    if let reconnectionIntent = queuedIntent {
                        return .connecting(.unresolved(reconnectionIntent))
                    }
                    assert(oldState, isNot: \.disconnected)
                    return .disconnecting(intent, intent.server)
                }

            case .core(.delegate(.stateChanged(_, .unknown))):
                return .send(.delegate(.stateChanged(.resolving)))

            case let .core(.delegate(.error(connectionError))):
                return .send(.delegate(.connectionFailed(connectionError)))

            case .core:
                return .none

            case .delegate:
                // It's up to the parent feature to respond to delegate actions
                return .none
            }
        }
    }

    /// Determine whether it is safe to disconnect. If so, proceed with internal disconnection logic. Otherwise, delay
    /// the disconnection request until the network extension state is stable and can be disconnected.
    private func handleUserDisconnectionRequest(_ state: inout State) -> Effect<Action> {
        let internalDisconnectOrStateChangeEffect: Effect<Action>
        switch state.coreConnectionState {
        case .unknown:
            state.core.shouldDisconnectWhenAllowed = true
            internalDisconnectOrStateChangeEffect = .none
            log.debug("Delaying disconnection request until internal state has been resolved", category: .connection)

        case .starting, .connecting:
            if state.core.isInteractionAllowed {
                internalDisconnectOrStateChangeEffect = .send(.core(.disconnect(.userIntent)))
            } else {
                log.debug("Delaying disconnection request until internally ready to disconnect", category: .connection)
                state.core.shouldDisconnectWhenAllowed = true
                internalDisconnectOrStateChangeEffect = updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    .disconnecting(intent, intent.server)
                }
            }

        case .connected:
            internalDisconnectOrStateChangeEffect = .send(.core(.disconnect(.userIntent)))

        case .disconnecting:
            if state.reconnectionIntent != nil {
                log.debug("Cancelling reconnection intent following disconnection intent from user", category: .connection)
                state.reconnectionIntent = nil
            } else {
                log.debug("Ignoring disconnection intent, already internally disconnected.", category: .connection)
            }
            internalDisconnectOrStateChangeEffect = updateStateWithStoredIntentOrDisconnect(&state) { intent in
                .disconnecting(intent, intent.server)
            }

        case .disconnected:
            log.info("Ignoring disconnection intent, already internally disconnected.", category: .connection)
            internalDisconnectOrStateChangeEffect = updateStateSendingEffectIfNecessary(&state, to: .disconnected)
        }
        return .merge(
            .cancel(id: CancelID.preparation),
            internalDisconnectOrStateChangeEffect
        )
    }

    private func updateStateWithStoredIntentOrDisconnect(
        _ state: inout State,
        calculateState: (ServerConnectionIntent) -> ConnectionState
    ) -> Effect<Action> {
        do {
            let intent = try state.currentIntent ?? intentStorage.getConnectionIntent()
            let newState = calculateState(intent)
            return updateStateSendingEffectIfNecessary(&state, to: newState)
        } catch {
            log.error("Failed to fetch stored connection intent", metadata: ["error": "\(error)"])
            return .concatenate(
                .send(.delegate(.connectionFailed(.intentMissing))),
                .send(.core(.disconnect(.connectionFailure(.intentMissing))))
            )
        }
    }

    /// Prevents sending duplicate state change actions, e.g. connecting -> connecting
    private func updateStateSendingEffectIfNecessary(
        _ state: inout State,
        to newValue: ConnectionState
    ) -> Effect<Action> {
        if state.connectionState == newValue {
            return .none
        }
        state.connectionState = newValue
        return .send(.delegate(.stateChanged(newValue)))
    }

    private func assert<T: CasePathable>(
        _ value: T,
        isNot unexpectedValue: PartialCaseKeyPath<T>,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        if value.is(unexpectedValue) {
            // VPNAPPL-2696 - Visibility of failed assertions could be improved by invoking `assertionFailure` when not running tests
            let message = "Assertion failed: \(value) is \(unexpectedValue)"
            log.error("\(message)", category: .connection)
            reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
        }
    }

    private func assert<T: CasePathable>(
        _ value: T,
        is expectedValue: PartialCaseKeyPath<T>,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        if !value.is(expectedValue) {
            // VPNAPPL-2696 - Visibility of failed assertions could be improved by invoking `assertionFailure` when not running tests
            let message = "Assertion failed: \(value) is not \(expectedValue)"
            log.error("\(message)", category: .connection)
            reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
        }
    }
}

extension ConnectionFeature.State {
    var coreConnectionState: CoreConnectionState {
        CoreConnectionState(connectionFeatureState: core)
    }
}

// User-facing connection state
@CasePathable
public enum ConnectionState: Equatable, Sendable {
    case resolving
    case disconnected
    case disconnecting(ServerConnectionIntent, Server)
    case connecting(Intent)
    case connected(ServerConnectionIntent, Server, Date, ConnectionDetailsMessage?)

    @CasePathable public enum Intent: Equatable, Sendable {
        case unresolved(ConnectionPreparationIntent)
        case resolved(ServerConnectionIntent, Server)
    }
}

extension ConnectionFeature.State {
    public static let initialState = ConnectionFeature.State(
        currentIntent: nil,
        queuedIntent: nil,
        connectionState: .resolving,
        shouldRegisterServerChangeOnConnection: false,
        core: .initialCoreConnectionState
    )
}
