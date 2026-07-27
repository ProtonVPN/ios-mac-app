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
import ConnectionShared
import CoreConnection
import Dependencies
import Domain
import Ergonomics
import ExtensionIPC
import ExtensionSync
import Foundation
import ProtonCoreFeatureFlags
import Strings
import VPNAppCore

@Reducer
public struct ExtensionFeature: Sendable {
    @Dependency(\.tunnelManager) var tunnelManager
    @Dependency(\.continuousClock) var clock
    @Dependency(\.forkSelectorClient) var forkSelectorClient

    private static let defaultConnectionTimeout = Duration.seconds(30)

    public init() {}

    private enum CancelID {
        case tunnelStart
        case observation
        case connectionTimeout
    }

    public typealias State = TunnelState

    public enum ReassertionReason: Sendable {
        case forkSelectorRequest
    }

    @DebugDescription
    public enum Action: Sendable {
        case startObserving
        case stopObserving
        /// Requests that the extension apply a partial configuration/feature change to the running tunnel.
        case requestConfigChange(ConnectionUpdate)
        case connect(ServerConnectionIntent)
        #if !os(tvOS)
            /// Start a zero-peer tunnel from a disconnected state (Advanced kill switch cold-start).
            case startZeroPeerColdStart
        #endif
        case tunnelStartRequestFinished(Result<Bool, Error>)
        /// The internal state of the network extension has changed
        case tunnelStatusChanged(TunnelState)
        /// The extension reported an error over the error channel (surfaced through `statusStream`).
        case tunnelErrored(ExtensionError)
        case timeout
        case tunnelReasserting(ReassertionReason?)
        case disconnect(TunnelConnectionError?)
        case cleanup

        case delegate(Delegate)

        @DebugDescription
        public enum Delegate: Sendable {
            case reconfigurationFailed(Error)
            /// A non-fatal error the extension reported (e.g. a server policy refusal or a config-update failure).
            case errorReported(ExtensionError)
            case timedOut(ConnectionStage)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startObserving:
                // Subscribe to state changes
                let initial: Effect<ExtensionFeature.Action> = .run { send in
                    let status = try await tunnelManager.status
                    return await send(.tunnelStatusChanged(status))
                }
                let observation: Effect<ExtensionFeature.Action> = .run { send in
                    for await result in tunnelManager.statusStream {
                        switch result {
                        case let .success(status):
                            await send(.tunnelStatusChanged(status))
                        case let .failure(error):
                            await send(.tunnelErrored(error))
                        }
                    }
                }
                let forkObservation: Effect<ExtensionFeature.Action> = .run { send in
                    for await _ in tunnelManager.forkRequestsStream {
                        await send(.tunnelReasserting(.forkSelectorRequest))
                    }
                }

                // These effects must not be executed concurrently until we make `PacketTunnelManager` concurrency safe.
                // Doing so has the potential to create a duplicate set of `NETunnelProviderManager` and `NEVPNSession`
                // objects, with us potentially observing the status changes of one pair, while sending `startTunnel`
                // and `stopTunnel` commands to the other, resulting in failure to connect.
                return .concatenate(
                    initial,
                    .merge(observation, forkObservation)
                        .cancellable(id: CancelID.observation, cancelInFlight: true)
                )

            case .stopObserving:
                return .merge(
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.connectionTimeout)
                )

            case let .requestConfigChange(update):
                return .run { _ in
                    log.debug("Requesting connection update", category: .connection, metadata: ["requestId": "\(update.id)"])
                    _ = try await tunnelManager.sendProTUN(request: .init(payload: .updateConfiguration(update)))
                } catch: { error, send in
                    log.error("Failed to apply connection update", category: .connection, metadata: ["error": "\(error)"])
                    SentryHelper.shared?.log(error: error)
                    await send(.delegate(.reconfigurationFailed(error)))
                }

            case let .connect(intent) where state.canUpdateConfiguration:
                // The tunnel is already up, so reconfigure it in-place instead of reconnecting. Route any failure
                // through `reconfigurationFailed` (never a disconnect) so the existing tunnel doesn't get torn down.
                return .run { send in
                    @Dependency(\.tunnelProviderConfigurator) var configurator
                    try await send(.requestConfigChange(configurator.changes(intent)))
                } catch: { error, send in
                    log.error("Failed to derive configuration changes", category: .connection, metadata: ["error": "\(error)"])
                    SentryHelper.shared?.log(error: error)
                    await send(.delegate(.reconfigurationFailed(error)))
                }

            case let .connect(intent):
                // Start the tunnel and, concurrently, arm the connection timeout. The timeout is cancelled once we
                // reach a terminal state for the attempt (connected / disconnected / start-request failure).
                return .merge(
                    .run { send in
                        await send(.tunnelStartRequestFinished(Result {
                            try await tunnelManager.startTunnel(with: intent)
                            try Task.checkCancellation()
                            // returning a Bool is to circumvent a compiler build issue with Result<Void, _> & CaseKeyPaths
                            return true
                        }))
                    }.cancellable(id: CancelID.tunnelStart),
                    .run { send in
                        try await clock.sleep(for: Self.defaultConnectionTimeout)
                        try Task.checkCancellation()
                        await send(.timeout)
                    } catch: { error, _ in
                        log.error("Timeout task cancellation error: \(error)", category: .connection)
                    }.cancellable(id: CancelID.connectionTimeout, cancelInFlight: true)
                )

            #if !os(tvOS)
                case .startZeroPeerColdStart:
                    // Cold start a peerless, includeAllNetworks tunnel to enforce Advanced kill switch blocking
                    // from a disconnected state
                    return .run { send in
                        await send(.tunnelStartRequestFinished(Result {
                            try await tunnelManager.startZeroPeerTunnel()
                            try Task.checkCancellation()
                            return true
                        }))
                    }.cancellable(id: CancelID.tunnelStart)
            #endif

            case .timeout:
                // Should we bump the timeout back to 30s every time the connection state advances?
                let stage = connectionStage(state) ?? .tunnel(.connection)
                return .merge(
                    .send(.delegate(.timedOut(stage))),
                    .send(.disconnect(nil))
                )

            case .tunnelStartRequestFinished(.success):
                // Tunnel has started, but we may still need to wait for connection to be established
                return .none

            case .tunnelReasserting(.forkSelectorRequest):
                // ProTUN asked us to (re-)fork the app's session selector so it can refresh its certificate. Forking
                // can fail (e.g. session expiry), so make sure the failure is handled by the reducer as well.
                return .run { [forkSelectorClient] _ in
                    try await forkSelectorClient.pushSelector()
                } catch: { error, send in
                    await send(.tunnelStartRequestFinished(.failure(error)))
                }

            case .tunnelReasserting:
                return .none

            case .tunnelStatusChanged(.invalid):
                // A notable scenario in which the tunnel state is invalid is before the user gives the app permission
                // to manage VPN configurations
                // VPNAPPL-3039: improve UX around requesting VPN configuration permissions
                state = .invalid
                return .none

            case let .tunnelStatusChanged(status):
                state = status
                switch status {
                case .connected, .disconnected:
                    return .cancel(id: CancelID.connectionTimeout)
                default:
                    return .none
                }

            case let .tunnelErrored(error):
                // A fatal certificate-refresh error tears the tunnel down, surfacing the reason through the
                // disconnected state. Every other reported error is forwarded to the parent and then acknowledged to
                // the extension via provider message, so that the app display state can quiesce.
                if error.decoded(as: ExtensionTunnelError.self) == .certificateRefreshFatalError {
                    log.error("Local Agent fatal certificate refresh error", category: .connection)
                    return .merge(
                        .send(.tunnelStatusChanged(.disconnected(.tunnelAborted))),
                        .send(.disconnect(.tunnelAborted))
                    )
                }

                log.warning("Extension reported error", category: .connection, metadata: ["error": "\(error)"])
                return .merge(
                    .send(.delegate(.errorReported(error))),
                    .run { [requestId = error.id] _ in
                        guard let requestId else { return }
                        _ = try await tunnelManager.sendProTUN(request: .init(payload: .ack(errorId: requestId)))
                    } catch: { error, _ in
                        log.error("Failed to acknowledge extension error", category: .connection, metadata: ["error": "\(error)"])
                    }
                )

            case .disconnect:
                return .merge(
                    .cancel(id: CancelID.tunnelStart),
                    .cancel(id: CancelID.connectionTimeout),
                    .run { send in
                        do {
                            try await tunnelManager.stopTunnel()
                        } catch {
                            // Sometimes the tunnel can go away without us knowing, make sure we have the latest state.
                            if let status = try? await tunnelManager.status {
                                await send(.tunnelStatusChanged(status))
                            }
                        }
                    } catch: { error, _ in
                        log.assertionFailure("Failed to stop tunnel: \(error)")
                    }
                )

            case let .tunnelStartRequestFinished(.failure(error)):
                // Two distinct failures land here: `startTunnel` failing before any provider is active, and a
                // fork-selector request failing while the tunnel is already alive (connecting). Surface the failure as
                // a disconnected state and attempt to stop the tunnel if it hasn't been stopped already (it's a no-op
                // otherwise).
                return .merge(
                    .cancel(id: CancelID.connectionTimeout),
                    .send(.tunnelStatusChanged(.disconnected(.tunnelStartFailed(error)))),
                    .run { _ in try? await tunnelManager.stopTunnel() }
                )

            case .cleanup:
                return .run { _ in
                    try await tunnelManager.cleanup()
                } catch: { error, _ in
                    log.assertionFailure("Failed to remove managers: \(error)")
                }

            case .delegate:
                return .none
            }
        }
    }

    /// Returns the connection stage the tunnel is currently in, or `nil` if fully connected.
    private func connectionStage(_ state: TunnelState) -> ConnectionStage? {
        switch state {
        case .connecting:
            .tunnel(.connection)
        case .connectingToLocalAgent:
            .connectingToLocalAgentServer
        case .disconnected:
            .tunnel(.start)
        case .invalid, .reasserting, .disconnecting, .unknown:
            // TODO: ProTUN: Error reporting - more connection stages
            nil
        case .connected, .killSwitchActive:
            nil
        }
    }
}

/// Used to provide more information about what stage of the connection process we reached before timing out.
@CasePathable
public enum ConnectionStage: Equatable, Sendable {
    /// We have failed to start the network extension process, or the extension failed to transition to the
    /// `connected` state.
    case tunnel(TunnelConnectionStage)
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

extension TunnelState {
    /// Whether the tunnel is in a state where its configuration can be updated in place, rather than requiring a fresh
    /// connection.
    var canUpdateConfiguration: Bool {
        switch self {
        case .unknown:
            // Can be returned when the app is just starting to resolve the tunnel state
            false
        case .invalid:
            // We don't even have permissions to write VPN configs
            false
        case .disconnected, .disconnecting:
            // We can't simply update the config, since the tunnel will have to be started
            false
        case let .connecting(config), let .connectingToLocalAgent(config):
            // An empty peer list is either zero-peer kill switch or a stale on-demand echo, neither of which can
            // accept a location update through this transitional state.
            config.tunnelProtocol == .wireGuard && !config.peerIDs.isEmpty
        case let .reasserting(config), let .connected(config, _), let .killSwitchActive(config):
            // Only ProTUN accepts in-place updates. IKEv2 has no extension to message, so its changes
            // always go through a fresh connection.
            config.tunnelProtocol == .wireGuard
        }
    }
}

@CasePathable
public enum TunnelConnectionError: Error, Equatable {
    /// Starting the tunnel failed, likely due to an operating system issue.
    case tunnelStartFailed(Error)
    /// The server is unknown or is no longer in the server list.
    case unknownServer
    /// The tunnel is in the incorrect state because it was prematurely disconnected
    case tunnelAborted

    case reconfigurationFailure(Error)

    public static func == (lhs: TunnelConnectionError, rhs: TunnelConnectionError) -> Bool {
        switch lhs {
        case .tunnelStartFailed:
            rhs.is(\.tunnelStartFailed)
        case .unknownServer:
            rhs.is(\.unknownServer)
        case .tunnelAborted:
            rhs.is(\.tunnelAborted)
        case .reconfigurationFailure:
            rhs.is(\.reconfigurationFailure)
        }
    }
}

extension TunnelConnectionError: ProtonVPNError {
    public static let errorDomain = "TunnelConnectionErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case let .tunnelStartFailed(vpnError as ProtonVPNError):
            vpnError.charCode
        case .tunnelStartFailed:
            "TNST"
        case .unknownServer:
            "UNKS"
        case .tunnelAborted:
            "TNAB"
        case .reconfigurationFailure:
            "TNRF"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .tunnelStartFailed(error as IkeConfiguratorError):
            if case .ikeCredentialsUnavailable = error {
                return includeCode(inside: Localizable.errorVpnCredentialsMissing)
            }
            return includeCode(inside: Localizable.connectionErrorTunnelConnection)
        case .tunnelStartFailed:
            return includeCode(inside: Localizable.connectionErrorTunnelConnection)
        default:
            return includeCode(inside: Localizable.connectionErrorTunnelConnection)
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .tunnelStartFailed(error):
            error
        default:
            nil
        }
    }
}

extension ExtensionFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .startObserving:
            ".startObserving"
        case .stopObserving:
            ".stopObserving"
        case let .connect(serverConnectionIntent):
            ".connect(\(serverConnectionIntent))"
        #if !os(tvOS)
            case .startZeroPeerColdStart:
                ".startZeroPeerColdStart"
        #endif
        case let .tunnelStartRequestFinished(result):
            ".tunnelStartRequestFinished(\(result))"
        case let .tunnelStatusChanged(tunnelState):
            ".tunnelStatusChanged(\(tunnelState))"
        case let .tunnelErrored(error):
            ".tunnelErrored(\(error))"
        case .timeout:
            ".timeout"
        case let .tunnelReasserting(reason):
            ".tunnelReasserting(\(String(describing: reason)))"
        case let .disconnect(tunnelConnectionError):
            ".disconnect(\(String(describing: tunnelConnectionError))"
        case .cleanup:
            ".cleanup"
        case let .requestConfigChange(update):
            ".requestConfigChange(\(update))"
        case let .delegate(action):
            ".delegate(\(action)"
        }
    }
}
