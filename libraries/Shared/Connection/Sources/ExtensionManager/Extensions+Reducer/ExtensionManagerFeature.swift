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

import ComposableArchitecture
import ConnectionShared
import CoreConnection
import Dependencies
import Domain
import Ergonomics
import ExtensionIPC
import Foundation
import ProtonCoreFeatureFlags
import Strings
import VPNAppCore

@Reducer
public struct ExtensionFeature: Sendable {
    @Dependency(\.tunnelManager) var tunnelManager

    public init() {}

    private enum CancelID {
        case tunnelStart
        case observation
    }

    public typealias State = TunnelState

    public enum ReassertionReason: Sendable {
        case forkSelectorRequest
    }

    @DebugDescription
    public enum Action: Sendable {
        case startObserving
        case stopObserving
        case updateConfiguration(ServerConnectionIntent)
        case applyConnectionUpdate(ConnectionUpdate)
        case connect(ServerConnectionIntent)
        case tunnelStartRequestFinished(Result<Bool, Error>)
        /// The internal state of the network extension has changed
        case tunnelStatusChanged(TunnelState)
        case tunnelReasserting(ReassertionReason?)
        case disconnect(TunnelConnectionError?)
        case cleanup

        case delegate(Delegate)

        @DebugDescription
        public enum Delegate: Sendable {
            case reconfigurationFailed(Error)
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
                    for await status in tunnelManager.statusStream {
                        await send(.tunnelStatusChanged(status))
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
                return .cancel(id: CancelID.observation)

            case let .updateConfiguration(intent):
                return .run { _ in
                    @Dependency(\.tunnelProviderConfigurator) var configurator
                    let changes = try configurator.changes(intent)
                    _ = try await tunnelManager.sendProTUN(request: .init(payload: .updateConfiguration(changes)))
                } catch: { error, send in
                    log.error("Failed to apply connection configuration changes", category: .connection, metadata: ["error": "\(error)"])
                    SentryHelper.shared?.log(error: error)
                    // TODO: ProTUN: Raise the derived set of (failed) configuration changes using the error
                    await send(.delegate(.reconfigurationFailed(error)))
                }

            case let .applyConnectionUpdate(update):
                return .run { _ in
                    _ = try await tunnelManager.sendProTUN(request: .init(payload: .updateConfiguration(update)))
                } catch: { error, send in
                    log.error("Failed to apply connection update", category: .connection, metadata: ["error": "\(error)"])
                    SentryHelper.shared?.log(error: error)
                    await send(.delegate(.reconfigurationFailed(error)))
                }

            case let .connect(intent):
                return .run { send in
                    await send(.tunnelStartRequestFinished(Result {
                        try await tunnelManager.startTunnel(with: intent)
                        try Task.checkCancellation()
                        // returning a Bool is to circumvent a compiler build issue with Result<Void, _> & CaseKeyPaths
                        return true
                    }))
                }.cancellable(id: CancelID.tunnelStart)

            case .tunnelStartRequestFinished(.success):
                // Tunnel has started, but we may still need to wait for connection to be established
                return .none

            case .tunnelReasserting:
                // handled by parents
                return .none

            case .tunnelStatusChanged(.invalid):
                // A notable scenario in which the tunnel state is invalid is before the user gives the app permission
                // to manage VPN configurations
                // VPNAPPL-3039: improve UX around requesting VPN configuration permissions
                state = .invalid
                return .none

            case let .tunnelStatusChanged(status):
                state = status
                return .none

            case let .disconnect(error):
                return .merge(
                    .cancel(id: CancelID.tunnelStart),
                    .run { _ in
                        try await tunnelManager.stopTunnel()
                    } catch: { error, _ in
                        log.assertionFailure("Failed to stop tunnel: \(error)")
                    }
                )

            case let .tunnelStartRequestFinished(.failure(error)):
                // Start request failed, so there's no need to disconnect
                state = .disconnected(.tunnelStartFailed(error))
                return .none

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
        case let .tunnelStartRequestFinished(result):
            ".tunnelStartRequestFinished(\(result))"
        case let .tunnelStatusChanged(tunnelState):
            ".tunnelStatusChanged(\(tunnelState))"
        case let .tunnelReasserting(reason):
            ".tunnelReasserting(\(String(describing: reason)))"
        case let .disconnect(tunnelConnectionError):
            ".disconnect(\(String(describing: tunnelConnectionError))"
        case .cleanup:
            ".cleanup"
        case let .updateConfiguration(serverConnectionIntent):
            ".updateConfiguration(\(serverConnectionIntent))"
        case let .applyConnectionUpdate(update):
            ".applyConnectionUpdate(\(update))"
        case let .delegate(action):
            ".delegate(\(action)"
        }
    }
}
