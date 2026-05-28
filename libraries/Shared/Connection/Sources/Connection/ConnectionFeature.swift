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

import Clocks
import ComposableArchitecture
import CoreConnection
import Dependencies
import Domain
import ExtensionManager
import Foundation
import LocalAgent
import Sharing
import VPNAppCore

@Reducer
public struct ConnectionFeature: Sendable {
    @Dependency(\.sessionChangeNotifier) private var sessionChangeNotifier
    @Dependency(\.connectionIntentStorage) private var intentStorage
    @Dependency(\.connectionIntentResolver) private var intentResolver
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.date) private var date
    @Dependency(\.wasLaunchedAtLogin) private var wasLaunchedAtLogin
    @Dependency(\.appProcessStartDate) private var appProcessStartDate
    @Dependency(\.serverIdentifier) private var serverIdentifier
    @Dependency(\.connectionFeatureProvider) private var connectionFeatureProvider

    public init() {}

    public struct State: Equatable, Sendable {
        @SharedReader(.userTier) public var userTier: Int?
        public internal(set) var currentIntent: ActiveConnectionIntent?
        public internal(set) var reconnectionIntent: ConnectionPreparationIntent?
        var connectionState: ConnectionState
        var shouldRegisterServerChangeOnConnection: Bool
        var reachabilityPendingIntent: ConnectionPreparationIntent?
        var core: CoreConnectionFeature.State

        package init(
            currentIntent: ActiveConnectionIntent?,
            queuedIntent: ConnectionPreparationIntent?,
            connectionState: ConnectionState,
            shouldRegisterServerChangeOnConnection: Bool,
            reachabilityPendingIntent: ConnectionPreparationIntent? = nil,
            core: CoreConnectionFeature.State
        ) {
            self.currentIntent = currentIntent
            self.reconnectionIntent = queuedIntent
            self.connectionState = connectionState
            self.shouldRegisterServerChangeOnConnection = shouldRegisterServerChangeOnConnection
            self.reachabilityPendingIntent = reachabilityPendingIntent
            self.core = core
        }
    }

    @DebugDescription
    public enum Action: Sendable {
        case prepare(ConnectionPreparationIntent)
        case finishedPreparing(Result<ServerConnectionIntent, ProtocolSelectionError>)
        case core(CoreConnectionFeature.Action)
        case input(Input)
        case reachabilityRetryDeadlineElapsed
        case delegate(Delegate)
        case stopObserving

        /// A subset of this reducer's actions suitable to be sent from outside
        @DebugDescription
        @CasePathable
        public enum Input: Sendable {
            case onLaunch
            case onLogout
            case connect(ConnectionPreparationIntent)
            case applySettings(Set<ConnectionFeatureChange.AgentFeature>)
            case onSessionChange
            case disconnect
        }

        /// A subset of this reducer's actions that must be handled appropriately by its parent
        @DebugDescription
        @CasePathable
        @dynamicMemberLookup
        public enum Delegate: Sendable {
            case stateChanged(ConnectionState)
            /// Emitted whenever the connection state transitions into `.disconnected`.
            /// Consumers should subscribe to this to react to "VPN is now fully down" — e.g.
            /// to invoke completion callbacks tied to a user-initiated disconnect.
            case disconnected
            case connectionFailed(ConnectionError)
            case intentResolutionFailed(ConnectionPreparationIntent, with: ConnectionIntentResolutionError)
            case localAgentNotice(LocalAgentTwoFactorAuthenticationError)
        }
    }

    private enum CancelID {
        case preparation
        case connectionTimeout
        case observation
        case reachabilityRetry
    }

    /// How long after process start we still consider the network potentially "warming up"
    /// (e.g. when the app was launched at login immediately following a device reboot, before
    /// network interfaces have come up). While inside this window, a connect request that
    /// finds the network unreachable is delayed rather than failed immediately.
    private static let deviceRebootReachabilityWindow: Duration = .seconds(10)

    /// How long we wait for the network to become reachable before surfacing a
    /// `.networkUnreachable` failure to the user, when a connect was deferred because
    /// the app is still inside ``deviceRebootReachabilityWindow``.
    private static let deviceRebootReachabilityDelay: Duration = .seconds(10)

    public var body: some Reducer<State, Action> {
        Scope(state: \.core, action: \.core) { CoreConnectionFeature() } // Firstly, process internal connection events
        Reduce { state, action in
            switch action {
            case .input(.onLaunch):
                return .merge(
                    .send(.core(.startObserving)),
                    // Surface session-change events (logout / guest→authenticated transition)
                    // as `.input(.onSessionChange)` so the connection layer can clean up
                    // tunnel + auth state.
                    .listen(to: sessionChangeNotifier.stream()) { _ in .input(.onSessionChange) }
                ).cancellable(id: CancelID.observation, cancelInFlight: true)

            case .stopObserving:
                state.reachabilityPendingIntent = nil
                return .merge(
                    .send(.core(.stopObserving)),
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.reachabilityRetry)
                )

            case let .input(.connect(intent)):
                // Explicit user connect should clear any stale delayed-disconnect latch
                // from previous cancelled attempts.
                state.core.shouldDisconnectWhenAllowed = false
                do throws(ConnectionIntentResolutionError) {
                    try intentResolver.authorize(intent, state.userTier ?? .freeTier)
                } catch {
                    return .send(.delegate(.intentResolutionFailed(intent, with: error)))
                }

                if state.core.currentNwStatus == .unsatisfied {
                    #if os(macOS)
                        if shouldDelayConnectionFailureBecauseOfStartup {
                            state.reachabilityPendingIntent = intent
                            return .run { send in
                                try await clock.sleep(for: Self.deviceRebootReachabilityDelay)
                                await send(.reachabilityRetryDeadlineElapsed)
                            }.cancellable(id: CancelID.reachabilityRetry, cancelInFlight: true)
                        }
                    #endif
                    return .send(.delegate(.connectionFailed(.preparation(.networkUnreachable))))
                }

                switch state.coreConnectionState {
                case .unknown:
                    // We are still resolving the startup state, so queue this intent and expose a connecting mask.
                    // Once we transition to disconnected, the queued intent will be prepared automatically.
                    state.reconnectionIntent = intent
                    let maskedConnectionState = ConnectionState.connecting(.unresolved(intent))
                    return updateStateSendingEffectIfNecessary(&state, to: maskedConnectionState)

                case .disconnecting:
                    // Save the reconnection intent for once the disconnection process is finished
                    state.reconnectionIntent = intent
                    // Disconnection could take some time (updating tunnel managers)
                    // Let's override user-facing state from disconnecting straight to connecting instead of waiting
                    let maskedConnectionState = ConnectionState.connecting(.unresolved(intent))
                    return updateStateSendingEffectIfNecessary(&state, to: maskedConnectionState)

                case .starting, .connecting, .connected:
                    state.reconnectionIntent = intent
                    guard state.core.isInteractionAllowed else {
                        log.debug(
                            "Delaying reconnect disconnection until core is ready",
                            category: .connection,
                            metadata: ["coreState": "\(state.coreConnectionState)"]
                        )
                        state.core.shouldDisconnectWhenAllowed = true
                        let maskedConnectionState = ConnectionState.connecting(.unresolved(intent))
                        return updateStateSendingEffectIfNecessary(&state, to: maskedConnectionState)
                    }
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
                state.reachabilityPendingIntent = nil
                // Logout transitions clear any tunnel; drop the delayed-disconnect latch so it
                // can't fire against a fresh post-logout connection attempt.
                state.core.shouldDisconnectWhenAllowed = false
                return .merge(.send(.stopObserving), .send(.core(.handleLogout)))

            case .input(.onSessionChange):
                state.reachabilityPendingIntent = nil
                // Session changes (logout, guest→authenticated, account switch) reset the
                // tunnel; any latch from a prior cancelled connect would no longer apply.
                state.core.shouldDisconnectWhenAllowed = false
                return .send(.core(.handleLogout))

            case .reachabilityRetryDeadlineElapsed:
                guard let pendingIntent = state.reachabilityPendingIntent else {
                    return .none
                }
                state.reachabilityPendingIntent = nil
                if state.core.currentNwStatus == .unsatisfied {
                    return .send(.delegate(.connectionFailed(.preparation(.networkUnreachable))))
                }
                return .send(.input(.connect(pendingIntent)))

            case let .prepare(intent):
                // protocol and port selection is only sensible while the tunnel is disconnected
                assert(state.coreConnectionState, is: \.disconnected)
                state.shouldRegisterServerChangeOnConnection = intent.spec.location == .any(.random)
                return .concatenate(
                    updateStateSendingEffectIfNecessary(&state, to: .connecting(.unresolved(intent))),
                    .run { send in
                        do throws(ProtocolSelectionError) {
                            let result = try await intentResolver.resolve(intent)
                            return await send(.finishedPreparing(.success(result)))
                        } catch {
                            return await send(.finishedPreparing(.failure(error)))
                        }
                    }.cancellable(id: CancelID.preparation, cancelInFlight: true)
                )

            case let .finishedPreparing(.success(resolvedIntent)):
                guard state.coreConnectionState.is(\.disconnected) else {
                    // Preparation can only be initiated while we are fully disconnected. If upon finishing preparation
                    // we are not disconnected, the tunnel was started externally. Let's disconnect with an error
                    log.error("Core connection state not disconnected after preparation", category: .connection)
                    return .send(.core(.disconnect(.connectionFailure(.preparation(.featureNotReady)))))
                }
                state.currentIntent = .active(resolvedIntent)
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
                return .concatenate(
                    updateStateSendingEffectIfNecessary(&state, to: .disconnected),
                    .send(.delegate(.connectionFailed(.preparation(.protocolSelectionError(error)))))
                )

            case let .core(.delegate(.stateChanged(_, .disconnected(.some(error))))):
                return .concatenate(
                    updateStateSendingEffectIfNecessary(&state, to: .disconnected),
                    .send(.delegate(.connectionFailed(error)))
                )

            case .core(.delegate(.stateChanged(_, .disconnected(nil)))):
                if let reconnectionIntent = state.reconnectionIntent {
                    assert(state.connectionState, is: \.connecting)
                    log.info("Disconnected, proceeding with reconnection to \(reconnectionIntent.spec)")
                    state.reconnectionIntent = nil
                    return .send(.prepare(reconnectionIntent))
                } else {
                    // Fully disconnected with no queued reconnect; clear any stale lifecycle intent.
                    state.currentIntent = nil
                    return updateStateSendingEffectIfNecessary(&state, to: .disconnected)
                }

            case let .core(.delegate(.stateChanged(_, .connected(connectionData, connectedAt, details)))):
                if state.currentIntent?.is(\.disconnecting) == true, state.reconnectionIntent != nil {
                    // Protocol-switch race only: this guard fires when we're in the middle of
                    // tearing down one tunnel while another reconnect intent is queued (e.g. the
                    // user toggled a setting that requires reconnect mid-session). It does NOT
                    // apply to the cancel-after-quick-connect path, where both `currentIntent`
                    // and `reconnectionIntent` are cleared in `handleUserDisconnectionRequest`.
                    // Suppress the transient `.connected` so the UI doesn't flash a connected
                    // state for the soon-to-be-torn-down tunnel before the queued reconnect
                    // takes over.
                    log.debug("Ignoring spurious .connected during protocol-switch reconnect", category: .connection)
                }
                if state.reconnectionIntent != nil {
                    // We can receive a late startup `.connected` after user already requested a new connection
                    // while state was still `.unknown`. Enforce a disconnect so only one tunnel/protocol stays active.
                    if state.core.isInteractionAllowed {
                        return .send(.core(.disconnect(.userIntent)))
                    }
                    state.core.shouldDisconnectWhenAllowed = true
                }
                if state.shouldRegisterServerChangeOnConnection {
                    @Dependency(\.serverChangeAuthorizer) var authorizer
                    authorizer.registerServerChange(connectedAt: connectedAt)
                }
                return resolveAndSetConnected(
                    &state,
                    connectionData: connectionData,
                    connectedAt: connectedAt,
                    details: details
                )

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
                if state.currentIntent?.is(\.disconnecting) == true {
                    // When disconnecting, local agent disconnects before the tunnel, briefly producing
                    // (tunnel: .connected, localAgent: .disconnected(nil)) which maps to CoreConnectionState.connecting.
                    // Suppress this spurious transition — we're still disconnecting.
                    log.debug("Ignoring spurious .connecting transition while disconnecting", category: .connection)
                    return .none
                }
                return updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    .connecting(.resolved(intent, intent.server))
                }

            case let .core(.delegate(.stateChanged(oldState, .disconnecting))):
                if case let .active(intent) = state.currentIntent {
                    state.currentIntent = .disconnecting(intent)
                }
                let queuedIntent = state.reconnectionIntent
                if let reconnectionIntent = queuedIntent {
                    // While reconnecting we already have the next unresolved intent and do not need
                    // to resolve a stored active intent in order to expose user-facing state.
                    return updateStateSendingEffectIfNecessary(&state, to: .connecting(.unresolved(reconnectionIntent)))
                }
                return updateStateWithStoredIntentOrDisconnect(&state) { intent in
                    assert(oldState, isNot: \.disconnected)
                    return .disconnecting(intent, intent.server)
                }

            case .core(.delegate(.stateChanged(_, .unknown))):
                let priorIntent = state.currentIntent?.serverIntent
                return .send(.delegate(.stateChanged(.resolving(priorIntent, priorIntent?.server))))

            case let .core(.delegate(.error(connectionError))):
                return .send(.delegate(.connectionFailed(connectionError)))

            case let .core(.localAgent(.notice(authenticationError))):
                return .send(.delegate(.localAgentNotice(authenticationError)))

            case let .core(.connectivityChanged(nwStatus)):
                guard nwStatus.shouldAttemptConnection,
                      let pendingIntent = state.reachabilityPendingIntent
                else {
                    return .none
                }
                state.reachabilityPendingIntent = nil
                return .merge(
                    .cancel(id: CancelID.reachabilityRetry),
                    .send(.input(.connect(pendingIntent)))
                )

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
        state.reachabilityPendingIntent = nil
        if state.reconnectionIntent != nil {
            log.debug("Clearing queued reconnection intent following explicit user disconnect", category: .connection)
            state.reconnectionIntent = nil
        }
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
            log.debug("Ignoring disconnection intent, already internally disconnected.", category: .connection)
            internalDisconnectOrStateChangeEffect = updateStateWithStoredIntentOrDisconnect(&state) { intent in
                .disconnecting(intent, intent.server)
            }

        case .disconnected:
            log.info("Ignoring disconnection intent, already internally disconnected.", category: .connection)
            // Keep a delayed-disconnect latch so that if a late tunnel start arrives
            // from a cancelled attempt, core will disconnect again as soon as possible.
            state.core.shouldDisconnectWhenAllowed = true
            internalDisconnectOrStateChangeEffect = .merge(
                // A tunnel start can still be in flight while core reports disconnected.
                // Forwarding a disconnect here ensures pending start effects are cancelled.
                .send(.core(.disconnect(.userIntent))),
                updateStateSendingEffectIfNecessary(&state, to: .disconnected)
            )
        }
        return .merge(
            .cancel(id: CancelID.preparation),
            .cancel(id: CancelID.reachabilityRetry),
            internalDisconnectOrStateChangeEffect
        )
    }

    private func updateStateWithStoredIntentOrDisconnect(
        _ state: inout State,
        calculateState: (ServerConnectionIntent) -> ConnectionState
    ) -> Effect<Action> {
        do {
            let intent = try state.currentIntent?.serverIntent ?? intentStorage.getConnectionIntent()
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

    /// Resolves the intent associated with a `.connected` event against the actual tunnel data.
    /// The stored intent (either `state.currentIntent` or the legacy `intentStorage` fallback) is
    /// used as-is only when its protocol and server identifier match what the OS reports;
    /// otherwise a fresh `ServerConnectionIntent` is synthesised from `connectionData`. This
    /// keeps the UI in sync with OS-initiated tunnels (e.g. the user starting a VPN from System
    /// Settings) where the stored in-app intent is necessarily stale or absent.
    private func resolveAndSetConnected(
        _ state: inout State,
        connectionData: ConnectionData,
        connectedAt: Date,
        details: ConnectionDetailsMessage?
    ) -> Effect<Action> {
        let actualTunnelProtocol = connectionData.protocolData.tunnelProtocol
        let actualServer = serverIdentifier.fullServerInfo(connectionData.serverID)
        let storedIntent = state.currentIntent?.serverIntent ?? (try? intentStorage.getConnectionIntent())

        let resolvedIntent: ServerConnectionIntent? = if let storedIntent,
                                                         tunnelProtocol(for: storedIntent.protocolConfiguration) == actualTunnelProtocol,
                                                         storedIntent.server.endpoint.id == connectionData.serverID {
            storedIntent
        } else if let server = actualServer ?? storedIntent?.server {
            ServerConnectionIntent(
                spec: storedIntent?.spec ?? ConnectionSpec(),
                server: server,
                protocolConfiguration: synthesizedProtocolConfiguration(
                    from: connectionData.protocolData,
                    preserving: storedIntent?.protocolConfiguration
                ),
                features: storedIntent?.features ?? connectionFeatureProvider.connectionFeatures()
            )
        } else {
            nil
        }

        guard let resolvedIntent else {
            log.error("Failed to resolve connection intent for .connected", category: .connection)
            return .concatenate(
                .send(.delegate(.connectionFailed(.intentMissing))),
                .send(.core(.disconnect(.connectionFailure(.intentMissing))))
            )
        }

        state.currentIntent = .active(resolvedIntent)
        return updateStateSendingEffectIfNecessary(
            &state,
            to: .connected(resolvedIntent, resolvedIntent.server, connectedAt, details)
        )
    }

    private func tunnelProtocol(for configuration: ProtocolConfiguration) -> TunnelProtocol {
        switch configuration {
        case .ike:
            .ike
        case let .wireGuard(settings):
            .wireGuard(settings.backend)
        }
    }

    /// Builds a `ProtocolConfiguration` matching the actual tunnel's `ProtocolConnectionData`.
    /// When the stored configuration's backend already matches the observed one (e.g. both WG
    /// with the same backend), the stored configuration is reused so its transport/ports/features
    /// are preserved; otherwise sensible defaults are filled in.
    private func synthesizedProtocolConfiguration(
        from protocolData: ProtocolConnectionData,
        preserving stored: ProtocolConfiguration?
    ) -> ProtocolConfiguration {
        switch protocolData {
        case .ike:
            return .ike
        case .wireGuardGo, .proTUN:
            let backend: WGBackend = protocolData == .proTUN ? .proTUN : .go
            if case let .wireGuard(storedSettings) = stored, storedSettings.backend == backend {
                return .wireGuard(storedSettings)
            }
            return .wireGuard(WireGuardSettings(
                backend: backend,
                transport: .defaultValue,
                ports: [],
                features: connectionFeatureProvider.tunnelFeatures()
            ))
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
        if newValue.is(\.disconnected) {
            return .merge(
                .send(.delegate(.stateChanged(newValue))),
                .send(.delegate(.disconnected))
            )
        }
        return .send(.delegate(.stateChanged(newValue)))
    }

    #if os(macOS)
        private var shouldDelayConnectionFailureBecauseOfStartup: Bool {
            guard wasLaunchedAtLogin(),
                  let processStartDate = appProcessStartDate()
            else {
                return false
            }
            let elapsed = Duration.seconds(abs(date.now.timeIntervalSince(processStartDate)))
            return elapsed < Self.deviceRebootReachabilityWindow
        }
    #endif

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

/// Wraps the resolved connection intent with its current lifecycle phase.
/// This allows `ConnectionFeature` to distinguish between the identical
/// `(tunnel: .connected, localAgent: .disconnected(nil))` state that occurs
/// both when initially connecting and when local agent disconnects before the tunnel during a disconnect.
@CasePathable
public enum ActiveConnectionIntent: Equatable, Sendable {
    case active(ServerConnectionIntent)
    case disconnecting(ServerConnectionIntent)

    public var serverIntent: ServerConnectionIntent {
        switch self {
        case let .active(intent), let .disconnecting(intent): intent
        }
    }
}

// User-facing connection state
@DebugDescription
@CasePathable
public enum ConnectionState: Equatable, Sendable {
    /// Transitional state used while the connection layer is determining the actual tunnel
    /// status (e.g. cold start, OS-level state change). Carries the prior intent and server
    /// when known so UI can preserve continuity ("we were connected to X") during the window.
    case resolving(ServerConnectionIntent?, Server?)
    case disconnected
    case disconnecting(ServerConnectionIntent, Server)
    case connecting(Intent)
    case connected(ServerConnectionIntent, Server, Date, ConnectionDetailsMessage?)

    @DebugDescription
    @CasePathable
    public enum Intent: Equatable, Sendable {
        case unresolved(ConnectionPreparationIntent)
        case resolved(ServerConnectionIntent, Server)
    }
}

public extension ConnectionFeature.State {
    static let initialState = ConnectionFeature.State(
        currentIntent: nil,
        queuedIntent: nil,
        connectionState: .resolving(nil, nil),
        shouldRegisterServerChangeOnConnection: false,
        reachabilityPendingIntent: nil,
        core: .initialCoreConnectionState
    )
}

extension ConnectionFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .prepare(intent):
            ".prepare(\(intent))"
        case let .finishedPreparing(result):
            ".finishedPreparing(\(result))"
        case let .core(action):
            ".core(\(action.debugDescription))"
        case let .input(input):
            ".input(\(input.debugDescription))"
        case let .delegate(delegate):
            ".delegate(\(delegate.debugDescription))"
        case .stopObserving:
            ".stopObserving"
        case .reachabilityRetryDeadlineElapsed:
            ".reachabilityRetryDeadlineElapsed"
        }
    }
}

extension ConnectionFeature.Action.Input: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .onLaunch:
            ".onLaunch"
        case .onLogout:
            ".onLogout"
        case let .connect(intent):
            ".connect(\(intent))"
        case let .applySettings(settings):
            ".applySettings(\(settings))"
        case .disconnect:
            ".disconnect"
        case .onSessionChange:
            ".onSessionChange"
        }
    }
}

extension ConnectionFeature.Action.Delegate: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .stateChanged(connectionState):
            ".stateChanged(\(connectionState))"
        case let .connectionFailed(connectionError):
            ".connectionFailed(\(connectionError))"
        case let .intentResolutionFailed(intent, resolutionError):
            ".intentResolutionFailed(\(intent), \(resolutionError))"
        case let .localAgentNotice(error):
            ".localAgentNotice(\(error.errorCodeString))"
        case .disconnected:
            ".stateChanged(.disconnected)"
        }
    }
}

extension ConnectionState: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .resolving(intent, server):
            ".resolving(intent: \(intent.map { "\($0)" } ?? "nil"), server: \(server.map { "\($0.logical.id)" } ?? "nil"))"
        case .disconnected:
            ".disconnected"
        case let .disconnecting(intent, server):
            ".disconnecting(intent: \(intent), server: \(server))"
        case let .connecting(intent):
            ".connecting(\(intent))"
        case let .connected(intent, server, date, message):
            ".connected(\(intent), \(server), \(date), \(String(describing: message)))"
        }
    }
}

extension ConnectionState.Intent: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .unresolved(intent):
            ".unresolved(\(intent))"
        case let .resolved(intent, server):
            ".resolved(\(intent), \(server))"
        }
    }
}
