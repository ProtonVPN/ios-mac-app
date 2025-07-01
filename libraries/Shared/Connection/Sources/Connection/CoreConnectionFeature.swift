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
import Network
import enum NetworkExtension.NEVPNStatus

import Clocks
import ComposableArchitecture
import Dependencies

import CertificateAuthentication
import CoreConnection
import ExtensionManager
import LocalAgent
import VPNAppCore

import Domain

/// Low-level reducer that handles connection logic internals. Mainly responsible for commmunication between its three
/// sub-features, as well as failing the connection whenever it times out.
public struct CoreConnectionFeature: Reducer, Sendable {
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.serverIdentifier) private var serverIdentifier
    @Dependency(\.tunnelKeychain) private var tunnelConfigKeychain
    @Dependency(\.connectionFeatureProvider) private var connectionFeatureProvider
    @Dependency(\.nwPathStatus) private var nwPathStatus

    private static let defaultConnectionTimeout = Duration.seconds(30)

    public init() {}

    /// In an effort to prevent duplicating state, we don't hold any state besides child feature state.
    /// There exists a `CoreConnectionState` enum which consolidates this information into a single piece of state,
    /// but it is not explicitly stored as part of this feature's state, or its parent's. Every time this reducer
    /// reduces an action (or set of actions, if they are returned immediately and not through an asynchronous effect),
    /// and the state has changed, a `Delegate.stateChanged` event is sent and should be handled appropriately by the
    /// parent.
    public struct State: Equatable, Sendable {
        public internal(set) var tunnel: ExtensionFeature.State
        public internal(set) var localAgent: LocalAgentFeature.State
        public internal(set) var certAuth: CertificateAuthenticationFeature.State
        public internal(set) var shouldDisconnectWhenAllowed: Bool
        public var currentNwStatus: NWPath.Status = .requiresConnection

        package init(
            tunnelState: ExtensionFeature.State = .unknown,
            certAuthState: CertificateAuthenticationFeature.State = .idle,
            localAgentState: LocalAgentFeature.State = .disconnected(nil),
            shouldDisconnectWhenAllowed: Bool = false
        ) {
            self.tunnel = tunnelState
            self.certAuth = certAuthState
            self.localAgent = localAgentState
            self.shouldDisconnectWhenAllowed = shouldDisconnectWhenAllowed
        }
    }

    @CasePathable
    @dynamicMemberLookup
    public enum Action: Sendable {
        /// Starts connection to the server with the protocol, tunnel and agent features specified in the intent.
        /// This action is only accepted in the fully `disconnected` state.
        case connect(ServerConnectionIntent)
        /// Starts the disconnection process.
        /// When sent with a `DisconnectReason.connectionFailure`, a delegate action containing the error is sent.
        case disconnect(DisconnectReason)
        /// Internal action sent after the `defaultConnectionTimeout` duration has elapsed following a connection
        /// intent. The reducer then inspects the state of child features to determine what stage we timed out at.
        case timeout
        /// Sends effects to start observing changes from dependencies owned by child features. Must be immediately
        /// sent by the parent in order to start resolving the initial connection state.
        case startObserving
        /// Cancels observation effects started by `startObserving`
        case stopObserving
        case connectivityChanged(NWPath.Status)
        /// Starts the disconnection process and clears relevant keychains and configurations
        case handleLogout
        /// Tunnel/NetworkExtension child reducer action
        case tunnel(ExtensionFeature.Action)
        /// Certificate authentication child reducer action
        case certAuth(CertificateAuthenticationFeature.Action)
        /// Local agent child reducer action
        case localAgent(LocalAgentFeature.Action)
        /// Delegate action expected to be handled by the parent
        case delegate(Delegate)

        /// A subset of actions expected to be handled by the parent
        @DebugDescription
        @CasePathable
        @dynamicMemberLookup
        public enum Delegate: Sendable {
            case error(ConnectionError)
            case stateChanged(CoreConnectionState, CoreConnectionState)
        }
    }

    @CasePathable
    public enum DisconnectReason: Equatable, Sendable {
        case connectionFailure(ConnectionError)
        case userIntent
    }

    private enum CancelID {
        case connectionTimeout
        case observation
        case nwPathReachability
    }

    /// The order of reducers here is important.
    ///  - Firstly, we save a copy of the internal state.
    ///  - Then, we run the child reducers individually, which can result in changes to said child state.
    ///  - After reducing child states, we run the `reduceCore` function which can further alter the state, and lastly
    ///    we check if the state has changed and append a `stateChanged` delegate action if it has.
    ///
    /// This state change calculation logic could likely be cleaned up with a higher order reducer instead.
    public var body: some Reducer<State, Action> {
        var oldStateCopy: State = .init()
        Reduce { state, _ in
            oldStateCopy = state
            return .none
        }
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() }
        Scope(state: \.certAuth, action: \.certAuth) { CertificateAuthenticationFeature() }
        Scope(state: \.localAgent, action: \.localAgent) { LocalAgentFeature() }
        Reduce { state, action in
            let effects = reduceCore(state: &state, action: action)
            return reduceWithStateChangeAction(oldState: oldStateCopy, newState: state, effects: effects)
        }
    }

    private func reduceCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startObserving:
            return .merge(
                .send(.tunnel(.startObservingStateChanges)),
                .send(.localAgent(.startObservingEvents)),
                .run { send in
                    for await status in await nwPathStatus() {
                        await send(.connectivityChanged(status))
                    }
                }.cancellable(id: CancelID.nwPathReachability)
            )
            .cancellable(id: CancelID.observation, cancelInFlight: true)

        case let .connectivityChanged(status):
            state.currentNwStatus = status
            return .none

        case .stopObserving:
            return .merge(
                .send(.tunnel(.stopObservingStateChanges)),
                .send(.localAgent(.stopAllObservations)),
                .cancel(id: CancelID.connectionTimeout),
                .cancel(id: CancelID.nwPathReachability)
            )

        case let .connect(intent):
            if !CoreConnectionState(connectionFeatureState: state).is(\.disconnected) {
                // This could happen if the tunnel is started externally during the connection preparation phase.
                // Check the README under ExtensionManagerFeature for more information about how the tunnel can be
                // started outside the app.
                // We trigger an assertion failure here because the parent feature should halt connection when this
                // happens.
                log.assertionFailure("Connection initiated, but feature is not ready", category: .connection)
                return .send(.disconnect(.connectionFailure(.preparation(.featureNotReady))))
            }
            clearErrorsFromPreviousAttempts(state: &state)

            return .concatenate(
                .send(.tunnel(.connect(intent))),
                .run { send in
                    try await clock.sleep(for: Self.defaultConnectionTimeout)
                    try Task.checkCancellation()

                    await send(.timeout)
                } catch: { error, _ in
                    log.error("Timeout task cancellation error: \(error)")
                }.cancellable(id: CancelID.connectionTimeout, cancelInFlight: true)
            )

        case let .disconnect(.connectionFailure(error)):
            // Disconnection initiated due to an error
            return .merge(
                .send(.delegate(.error(error))),
                certificateRefreshCancellation,
                .cancel(id: CancelID.connectionTimeout),
                .send(.localAgent(.disconnect(nil))),
                .send(.tunnel(.disconnect(nil)))
            )

        case .disconnect(.userIntent):
            return .merge(
                .cancel(id: CancelID.connectionTimeout),
                certificateRefreshCancellation,
                .send(.localAgent(.disconnect(nil))),
                .send(.tunnel(.disconnect(nil)))
            )

        case let .tunnel(.connectionFinished(.success(tunnelResponse))):
            // The network extension has been configured and launched (possibly during a previous run of the app).
            // It has replied with the id of the logical and endpoint that it believes it is connected to, and we have
            // confirmed that a server with such ids exists in our server database.
            log.info(
                "Tunnel connection finished",
                category: .connection,
                metadata: ["date": "\(tunnelResponse.connectionDate)", "logical": "\(tunnelResponse.logicalInfo)"]
            )
            // It's now safe to continue disconnecting
            if state.shouldDisconnectWhenAllowed {
                state.shouldDisconnectWhenAllowed = false
                log.info("Proceeding with delayed disconnection request", category: .connection)
                return .send(.disconnect(.userIntent))
            }
            if !state.localAgent.is(\.disconnected) {
                log.assertionFailure("Local agent wasn't disconnected when tunnel connection finished")
            }
            // Let's dive into the keychain and see if there's a valid certificate we can use to connect to the local agent server with.
            return .send(.certAuth(.loadAuthenticationData))

        case let .certAuth(.loadingFinished(.success(authData))):
            guard case let .connected(tunnelConnectionInfo) = state.tunnel else {
                log.error("Finished loading auth data but tunnel is not connected")
                return .send(.disconnect(.connectionFailure(.tunnel(.tunnelAborted))))
            }
            guard let server = serverIdentifier.fullServerInfo(tunnelConnectionInfo.logicalInfo) else {
                // VPNAPPL-2733: Don't disconnect until user acknowleges the alert.
                log.error("Detected connection to unknown server, disconnecting", category: .connection)
                return .send(.disconnect(.connectionFailure(.serverMissing)))
            }
            let data = VPNAuthenticationData(clientKey: authData.keys.privateKey, clientCertificate: authData.certificate.certificate)
            let features = connectionFeatureProvider.connectionFeatures()
            if authData.certificate.isExpired || authData.certificate.shouldBeRefreshed {
                log.assertionFailure("Loaded expired certificate")
                // loading finished with success, so there should be a valid certificate in the keychain.
                // let's try to handle this by clearing everything and reconnecting
                return .concatenate(
                    .send(.certAuth(.clearEverything)),
                    .send(.certAuth(.loadAuthenticationData))
                )
            }
            log.debug(
                "Starting local agent connection process",
                category: .connection,
                metadata: ["certificateValidUntil": "\(authData.certificate.validUntil)"]
            )
            // The tunnel has been established, we know what server to connect to, and we have a valid certificate
            return .send(.localAgent(.connect(server.endpoint, data, features, state.currentNwStatus != .unsatisfied)))

        case let .certAuth(.loadingFinished(.failure(error))):
            log.error("Failed to load authentication data: \(error)")
            // We encountered an unrecoverable failure to load, fetch or refresh a certificate. Disconnect with the error
            return .send(.disconnect(.connectionFailure(.certAuth(error))))

        case .tunnel(.tunnelStatusChanged(.disconnected)):
            state.shouldDisconnectWhenAllowed = false
            if case .disconnected = state.localAgent {
                // Now that we're fully disconnected, let's cancel the timeout
                return .cancel(id: CancelID.connectionTimeout)
            }
            // Local agent disconnection is normally instant. If LA still connected, but the tunnel has already
            // finished disconnecting, it either crashed, or was stopped by the system or as a result of user actions
            // outside the app. Let's disconnect from local agent as well.
            log.info("Tunnel disconnected while Local Agent was still active", category: .connection)
            return .send(.localAgent(.disconnect(nil)))

        case .tunnel(.tunnelStartRequestFinished(.failure)):
            // Special case of failure that occurs before the tunnel is started.
            // This could be due to keychain problems or tunnel configuration errors
            return .cancel(id: CancelID.connectionTimeout)

        case let .localAgent(.delegate(.connectionFailed(error))):
            // An error occurred while creating the local agent connection
            // This is likely due to a problem with our keys/certificate. Let's disconnect
            let connectionError = ConnectionError.agent(.failedToEstablishConnection(error))
            return .merge(
                // Attempt to resolve the root cause of failing to connect (GoTLSError)
                .send(.certAuth(.regenerateKeys)), // also removes the certificate
                .send(.disconnect(.connectionFailure(connectionError)))
            )

        case .localAgent(.event(.state(.disconnected))):
            guard case .disconnected = state.tunnel else { return .none }
            // Now that we're fully disconnected, let's cancel the timeout
            return .cancel(id: CancelID.connectionTimeout)

        case .localAgent(.event(.state(.connected))):
            // Local agent connection has been created, and we received a response from the server
            return .cancel(id: CancelID.connectionTimeout)

        case let .localAgent(.delegate(.errorReceived(error))):
            // We've received a local agent error
            @Dependency(\.date) var date
            if case .reconnect(.withNewCertificate) = error.resolutionStrategy, case let .loaded(data) = state.certAuth, date.now < data.certificate.validUntil {
                // LA seems to sometimes return a certExpired error when connecting to restricted servers, even when
                // our certificate is still valid. If our loaded certificate is still valid, let's ignore this error
                log.info(
                    "Ignoring certExpired error from LocalAgent, certificate is still valid",
                    category: .connection,
                    metadata: ["validUntil": "\(data.certificate.validUntil)", "refreshTime": "\(data.certificate.refreshTime)"]
                )
                return .none
            }
            log.info(
                "Handling LocalAgent error",
                category: .connection,
                metadata: ["error": "\(error)", "strategy": "\(error.resolutionStrategy)"]
            )
            return effectToResolve(error: error)

        case .timeout:
            // Maximum allowed connection duration has been exceeded, so we must terminate the connection attempt.
            // Let's inspect the state of the child features to determine what stage we have reached and disconnect.
            let currentConnectionStage = getConnectionStage(state)
            return .send(.disconnect(.connectionFailure(.timeout(currentConnectionStage))))

        case .tunnel:
            return .none

        case .localAgent:
            return .none

        case .certAuth:
            return .none

        case .handleLogout:
            do {
                try tunnelConfigKeychain.clear()
            } catch {
                // An error will be thrown if we haven't made any connections and there is nothing to clear.
                log.debug("Error clearing VPN keychain: \(error)")
            }
            return .merge(
                .send(.tunnel(.removeManagers)),
                .send(.certAuth(.clearEverything))
            )

        case .delegate:
            return .none
        }
    }

    /// Cancel any in-flight effects that may have resulted in IPC messages such as `refreshCertificate`
    /// This prevents us from raising unnecessary certificate authentication errors after disconnecting.
    /// While this could be a separate action on the child feature, it would require extra assertions in exhaustive
    /// tests.
    ///
    /// I've defined the effect here, since it is sent in more than one scenario, and so that we can avoid duplicating
    /// the explanation.
    ///
    /// Note: We can't avoid sending a whole action by using a `.cancel` effect, such as:
    /// `.cancel(CertificateAuthenticationFeature.CancelID.certificateRefreshAndRetries)`
    /// because when doing so, the `.run` tasks are no longer cancelled - it seems that `.cancel` effects only cancel
    /// tasks started by the feature in which they are processed, and do not affect tasks spawned by child reducers
    private let certificateRefreshCancellation: Effect<Action> = .send(.certAuth(.cancelRefreshes))

    private func effectToResolve(error: LocalAgentError) -> Effect<Action> {
        switch error.resolutionStrategy {
        case .none:
            .none

        case .disconnect(.immediately):
            .merge(
                .cancel(id: CancelID.connectionTimeout),
                .send(.localAgent(.disconnect(.agentError(error)))),
                .send(.tunnel(.disconnect(nil)))
            )

        case .disconnect(.withNewKeys):
            .merge(
                .cancel(id: CancelID.connectionTimeout),
                .send(.certAuth(.regenerateKeys)), // also removes the certificate
                .send(.localAgent(.disconnect(.agentError(error)))),
                .send(.tunnel(.disconnect(nil))) // VPNAPPL-2733: Don't disconnect until user acknowleges the alert.
            )

        case .reconnect(.withNewCertificate):
            .concatenate(
                .send(.localAgent(.disconnect(nil))),
                .send(.certAuth(.loadAuthenticationData)) // will refresh our certificate
            )

        case .reconnect(.withExistingCertificate):
            .concatenate(
                .send(.localAgent(.disconnect(nil))),
                .send(.certAuth(.loadAuthenticationData)) // *may* refresh our certificate
            )
        }
    }

    private func clearErrorsFromPreviousAttempts(state: inout State) {
        if case let .disconnected(tunnelError) = state.tunnel, let tunnelError {
            log.info("Resetting tunnel connection error from previous connection attempt: \(tunnelError)")
            state.tunnel = .disconnected(nil)
        }
        if case let .failed(certAuthError) = state.certAuth {
            log.info("Resetting cert auth error from previous connection attempt: \(certAuthError)")
            state.certAuth = .idle
        }
        if case let .disconnected(agentError) = state.localAgent, let agentError {
            log.info("Resetting local agent connection error from previous connection attempt: \(agentError)")
            state.localAgent = .disconnected(nil)
        }
    }

    private func reduceWithStateChangeAction(
        oldState: CoreConnectionFeature.State,
        newState: CoreConnectionFeature.State,
        effects: Effect<Action>
    ) -> Effect<Action> {
        let oldValue = CoreConnectionState(connectionFeatureState: oldState)
        let newValue = CoreConnectionState(connectionFeatureState: newState)
        if oldValue == newValue {
            return effects
        }
        if oldValue.is(\.disconnected.some), newValue.is(\.disconnected.none) {
            // Let's not report a core state change when clearing errors.
            return effects
        }
        return .concatenate(.send(.delegate(.stateChanged(oldValue, newValue))), effects)
    }

    private func getConnectionStage(_ state: State) -> ConnectionStage {
        guard state.tunnel.is(\.connected) else {
            return .tunnelStartingAndConnecting
        }
        guard state.certAuth.is(\.loaded) else {
            return .refreshingCertificate
        }
        guard state.localAgent.is(\.connected) else {
            return .connectingToLocalAgentServer
        }
        log.assertionFailure("Connection timed out, but all components are connected/ready", category: .connection)
        return .connectingToLocalAgentServer
    }

    /// Used to provide more information about what stage of the connection process we reached before timing out.
    @CasePathable
    public enum ConnectionStage: Equatable, Sendable {
        /// We have failed to start the network extension process, or the the extension failed to transition to the
        /// `connected` state.
        case tunnelStartingAndConnecting
        /// We've established the tunnel to the server, but failed to refresh our certificate.
        /// The refresh process can time out during the following:
        ///  - forking our main app session
        ///  - consuming of the forked session selector by the network extension
        ///  - refreshing of the forked session by the network extension
        ///  - refreshing of the certificate.
        ///  It's not currently possible to distinguish between the last three cases, since this requires knowledge of
        ///  what state the extension's `CertificateRefreshManager` is in.
        case refreshingCertificate
        /// We've established the tunnel to the server, and we have a valid certificate, but we've not been able to
        /// establish a connection to the Local Agent remote server.
        case connectingToLocalAgentServer
    }
}

extension CoreConnectionFeature.State {
    public static let initialCoreConnectionState: CoreConnectionFeature.State = .init(
        tunnelState: .unknown,
        certAuthState: .idle,
        localAgentState: .disconnected(nil)
    )

    /// Network extension behaviour is undefined (at least to us) if we invoke `stopTunnel` before the tunnel enters
    /// either `.connected` or `disconnected` states following the call to `startTunnel `
    package var isInteractionAllowed: Bool {
        tunnel.isInteractionAllowed
    }
}

extension CoreConnectionFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .connect(serverConnectionIntent):
            ".connect(\(serverConnectionIntent))"
        case let .disconnect(disconnectReason):
            ".disconnect(\(disconnectReason))"
        case .timeout:
            ".timeout"
        case .startObserving:
            ".startObserving"
        case .stopObserving:
            ".stopObserving"
        case .handleLogout:
            ".handleLogout"
        case let .tunnel(action):
            ".tunnel(\(action.debugDescription))"
        case let .certAuth(action):
            ".certAuth(\(action.debugDescription))"
        case let .localAgent(action):
            ".localAgent(\(action.debugDescription))"
        case let .delegate(delegate):
            ".delegate(\(delegate.debugDescription))"
        }
    }
}

extension CoreConnectionFeature.Action.Delegate: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .error(connectionError):
            ".error(\(connectionError))"
        case let .stateChanged(previousState, newState):
            ".stateChanged(\(previousState), \(newState))"
        }
    }
}
