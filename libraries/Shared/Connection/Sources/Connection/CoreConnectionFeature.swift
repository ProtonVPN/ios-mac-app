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

import Clocks
import ComposableArchitecture
import CoreConnection
import Dependencies
import Domain
import ExtensionManager
import Foundation
import LocalAgent
import LocalAgentIPC
import Network
import enum NetworkExtension.NEVPNStatus
import VPNAppCore

/// Low-level reducer that handles connection logic internals. Mainly responsible for commmunication between its three
/// sub-features, as well as failing the connection whenever it times out.
@Reducer
public struct CoreConnectionFeature: Sendable {
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.serverIdentifier) private var serverIdentifier
    @Dependency(\.nwStatusStream) private var nwStatusStream

    private static let defaultConnectionTimeout = Duration.seconds(30)
    private static let disconnectWaitTimeout = Duration.milliseconds(150)

    public init() {}

    public struct State: Equatable, Sendable {
        public internal(set) var tunnel: ExtensionFeature.State

        package init(
            tunnelState: ExtensionFeature.State = .unknown
        ) {
            self.tunnel = tunnelState
        }
    }

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
        /// Starts the disconnection process and clears relevant keychains and configurations
        case handleLogout
        /// Tunnel/NetworkExtension child reducer action
        case tunnel(ExtensionFeature.Action)
        /// Traffic / NetShield stats posted from the extension.
        case statsReceived(LocalAgent.Stats)
        /// Delegate action expected to be handled by the parent
        case delegate(Delegate)

        /// A subset of actions expected to be handled by the parent
        @DebugDescription
        @CasePathable
        @dynamicMemberLookup
        public enum Delegate: Sendable {
            case error(ConnectionError)
            case stateChanged(TunnelState)
            /// A feature change was confirmed by the extension. The new effective features are attached.
            case featuresChanged(VPNConnectionFeatures)
            /// A feature change failed with an error.
            case featureChangeFailed(reason: String)
        }
    }

    @CasePathable
    public enum DisconnectReason: Equatable, Sendable {
        case connectionFailure(ConnectionError)
        case userIntent
    }

    private enum CancelID {
        case connectionTimeout
        case localAgentStats
        case connectionErrors
    }

    /// The order of reducers here is important.
    ///  - Firstly, we save a copy of the internal state.
    ///  - Then, we run the child reducers individually, which can result in changes to said child state.
    ///  - After reducing child states, we run the `reduceCore` function which can further alter the state, and lastly
    ///    we check if the state has changed and append a `stateChanged` delegate action if it has.
    ///
    /// This state change calculation logic could likely be cleaned up with a higher order reducer instead.
    public var body: some Reducer<State, Action> {
        Scope(state: \.tunnel, action: \.tunnel) { ExtensionFeature() } // Firstly, process tunnel child events
        Reduce { state, action in
            switch action {
            case .startObserving:
                return .merge(
                    .send(.tunnel(.startObserving)),
                    .run { send in
                        @Dependency(\.localAgent) var localAgent
                        for await payload in localAgent.trafficStatsStream() {
                            await send(.statsReceived(payload.localAgentStats))
                        }
                    }.cancellable(id: CancelID.localAgentStats),
                    .run { send in
                        // The error stream from the network extension, communicated via RawChannel.
                        @Dependency(\.localAgent) var localAgent
                        for await payload in localAgent.errorStream() {
                            guard payload.hasError else { continue }
                            let localAgentError = payload.localAgentError
                            if case .certificateRefreshFatalError? = localAgentError {
                                log.error("Local Agent fatal certificate refresh error (error channel)", category: .connection)
                                await send(.disconnect(.connectionFailure(.tunnel(.tunnelAborted))))
                                continue
                            }
                            let reason = if case let .localAgentSettingPolicyRefused(setting)? = localAgentError {
                                "Local Agent refused setting: \(setting)"
                            } else {
                                "\(payload.errorDomain) (code \(payload.code))"
                            }
                            log.warning(
                                "Connection error received",
                                category: .connection,
                                metadata: ["reason": "\(reason)"]
                            )
                            await send(.delegate(.featureChangeFailed(reason: reason)))
                        }
                    }.cancellable(id: CancelID.connectionErrors)
                )

            case .stopObserving:
                return .merge(
                    .send(.tunnel(.stopObserving)),
                    .cancel(id: CancelID.connectionTimeout),
                    .cancel(id: CancelID.localAgentStats),
                    .cancel(id: CancelID.connectionErrors)
                )

            case let .connect(intent):
                if state.tunnel.canUpdateConfiguration {
                    return .send(.tunnel(.updateConfiguration(intent)))
                }

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
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.tunnel(.disconnect(nil)))
                )

            case .disconnect(.userIntent):
                return .merge(
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.tunnel(.disconnect(nil)))
                )

            case let .tunnel(.tunnelStatusChanged(.connected(tunnelConfig, connectionData))):
                log.info(
                    "Tunnel connection finished",
                    category: .connection,
                    metadata: ["date": "\(connectionData.connectionDate)", "serverID": "\(optional: connectionData.currentPeerId)"]
                )

                return .merge(
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.delegate(.stateChanged(.connected(tunnelConfig, connectionData))))
                )

            case let .tunnel(.tunnelStatusChanged(.disconnected(error))):
                return .merge(
                    // Now that we're fully disconnected, let's cancel the timeout
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.delegate(.stateChanged(.disconnected(error))))
                )

            case let .tunnel(.tunnelStatusChanged(status)):
                return .send(.delegate(.stateChanged(status)))

            case .tunnel(.tunnelReasserting(.forkSelectorRequest)):
                return .run { _ in
                    @Dependency(\.forkSelectorClient) var forkSelectorClient
                    try await forkSelectorClient.pushSelector()
                } catch: { error, send in
                    await send(.tunnel(.tunnelStartRequestFinished(.failure(error))))
                }

            case .tunnel(.tunnelStartRequestFinished(.failure)):
                // Special case of failure that occurs before the tunnel is started.
                // This could be due to keychain problems or tunnel configuration errors
                return .cancel(id: CancelID.connectionTimeout)

            case .timeout:
                // Maximum allowed connection duration has been exceeded, so we must terminate the connection attempt.
                // Let's inspect the state of the child features to determine what stage we have reached and disconnect.
                let currentConnectionStage = getConnectionStage(state)
                return .send(.disconnect(.connectionFailure(.timeout(currentConnectionStage ?? .connectingToLocalAgentServer))))

            case let .tunnel(.delegate(.reconfigurationFailed(error))):
                return .send(.delegate(.error(.tunnel(.reconfigurationFailure(error)))))

            case let .tunnel(.delegate(.featuresChanged(features))):
                return .send(.delegate(.featuresChanged(features)))

            case .tunnel:
                return .none

            case .statsReceived:
                return .none

            case .handleLogout:
                return .send(.tunnel(.cleanup))

            case .delegate:
                return .none
            }
        }
    }

    /// Returns the connection stage which the tunnel is currently in, or nil if fully connected.
    private func getConnectionStage(_ state: State) -> ConnectionStage? {
        switch state.tunnel {
        case .connected:
            nil
        case .connecting:
            .tunnel(.connection)
        // TODO: ProTUN: More connection stages, depending on internal ProTUN state
        case .disconnected:
            .tunnel(.start)
        case .invalid, .reasserting, .disconnecting, .unknown:
            // TODO: ProTUN: Error reporting - more connection stages
            nil
        }
    }

    /// Used to provide more information about what stage of the connection process we reached before timing out.
    @CasePathable
    public enum ConnectionStage: Equatable, Sendable {
        /// We have failed to start the network extension process, or the the extension failed to transition to the
        /// `connected` state.
        case tunnel(TunnelConnectionStage)
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

        @CasePathable
        public enum TunnelConnectionStage: Equatable, Sendable {
            /// Before a tunnel can be started, a valid VPN configuration must be saved in the system settings.
            /// Saving a configuration requires explicit user permission, which the system prompts for the first time
            /// the app attempts to save one.
            ///
            /// A connection attempt may time out at this stage if:
            ///  - the user does not enter their passcode within the timeout window
            ///  - the system fails to present the VPN configuration screen or passcode prompt
            case configuration
            /// A connection attempt may time out at this stage if we successfully configure the tunnel, but never
            /// observe it transitioning to the `.connecting` state. This can happen due to incorrectly set up
            /// `NEVPNStatusDidChange` notifications observers.
            case start
            /// We time out with this error if we successfully configure the tunnel, but never observe it transitioning
            /// to the `.connected` state.
            case connection
        }
    }
}

extension TunnelState {
    var canUpdateConfiguration: Bool {
        switch self {
        case .unknown:
            // TODO: ProTUN: better way to handle this? Should we even remove this state?
            false

        case .invalid:
            // We don't even have permissions to write VPN configs
            false

        case .disconnected, .disconnecting:
            // We can't simply update the config, since the tunnel will have to be started
            false

        case .reasserting, .connecting, .connected:
            true
        }
    }
}

public extension CoreConnectionFeature.State {
    /// At startup, we don't want to assume that we have a configuration saved already.
    /// After we subscribe to tunnel status changes, we will soon update the internal state to the appropriate
    /// value, and also update the masked state accordingly.
    static let initialCoreConnectionState: CoreConnectionFeature.State = .init(
        tunnelState: .unknown
    )
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
        case let .statsReceived(stats):
            ".statsReceived(\(stats))"
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
        case let .stateChanged(newState):
            ".stateChanged(\(newState))"
        case let .featuresChanged(features):
            ".featuresChanged(\(features))"
        case let .featureChangeFailed(reason):
            ".featureChangeFailed(\(reason))"
        }
    }
}
