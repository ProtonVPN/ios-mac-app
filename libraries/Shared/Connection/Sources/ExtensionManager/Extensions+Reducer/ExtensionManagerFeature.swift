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

import ComposableArchitecture
import Dependencies

import ConnectionShared
import CoreConnection
import ExtensionIPC
import VPNAppCore

import Domain
import Ergonomics
import ProtonCoreFeatureFlags
import Strings

@Reducer
public struct ExtensionFeature: Sendable {
    @Dependency(\.tunnelManager) var tunnelManager

    public init() {}

    private enum CancelID {
        case tunnelStart
        case observation
    }

    public typealias State = TunnelState

    @DebugDescription
    public enum Action: Sendable {
        case startObservingStateChanges
        case stopObservingStateChanges
        case connect(ServerConnectionIntent)
        case tunnelStartRequestFinished(Result<Bool, Error>)
        /// The internal state of the network extension has changed
        case tunnelStatusChanged(TunnelState)
        case disconnect(TunnelConnectionError?)
        case cleanup
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startObservingStateChanges:
                // Subscribe to state changes
                let initial: Effect<ExtensionFeature.Action> = .run { send in
                    let status = try await tunnelManager.status
                    return await send(.tunnelStatusChanged(status))
                }
                let observation: Effect<ExtensionFeature.Action> = .run { send in
                    for await status in try await tunnelManager.statusStream {
                        await send(.tunnelStatusChanged(status))
                    }
                }
                .cancellable(id: CancelID.observation, cancelInFlight: true)

                // These effects must not be executed concurrently until we make `PacketTunnelManager` concurrency safe.
                // Doing so has the potential to create a duplicate set of `NETunnelProviderManager` and `NEVPNSession`
                // objects, with us potentially observing the status changes of one pair, while sending `startTunnel`
                // and `stopTunnel` commands to the other, resulting in failure to connect.
                return .concatenate(initial, observation)

            case .stopObservingStateChanges:
                return .cancel(id: CancelID.observation)

            case let .connect(intent):
                state = .connecting
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

            case let .tunnelStatusChanged(.connected(tunnelProtocol, connectionData)):
                guard let connectionData else {
                    return .send(.disconnect(.unknownServer))
                }
                state = .connected(tunnelProtocol, connectionData)
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

    public static func == (lhs: TunnelConnectionError, rhs: TunnelConnectionError) -> Bool {
        switch lhs {
        case .tunnelStartFailed:
            rhs.is(\.tunnelStartFailed)
        case .unknownServer:
            rhs.is(\.unknownServer)
        case .tunnelAborted:
            rhs.is(\.tunnelAborted)
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
        }
    }

    public var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorTunnelConnection)
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

package extension TunnelState {
    /// The network extension process has a mind of its own. If we've previously invoked `startTunnel`, and we invoke
    /// `stopTunnel` before waiting for the extension to actually transition to `.connected` or `.disconnected`, we
    /// may get unexpected results. For now, the parent feature should delay disconnection until this feature is ready
    /// to accept such events.
    var isInteractionAllowed: Bool {
        switch self {
        case .connected, .disconnected:
            true

        case .connecting:
            // Technically, the network extension could be ready for interaction in this state. Currently, the
            // extension enters this state when we receive a `NEVPNStatusDidChange.connecting` notification, but we
            // don't leave it for `.connected` after we receive `NEVPNStatusDidChange.connected`, until we also
            // complete an ipc round trip to determine what server we are connected to. As a result, we will take
            // slightly longer to cancel our connection.
            // This could be improved by storing the last `NEVPNStatus` received in our state.
            false

        case .unknown, .invalid, .reasserting, .disconnecting:
            false
        }
    }
}

extension ExtensionFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .startObservingStateChanges:
            ".startObservingStateChanges"
        case .stopObservingStateChanges:
            ".stopObservingStateChanges"
        case let .connect(serverConnectionIntent):
            ".connect(\(serverConnectionIntent))"
        case let .tunnelStartRequestFinished(result):
            ".tunnelStartRequestFinished(\(result))"
        case let .tunnelStatusChanged(tunnelState):
            ".tunnelStatusChanged(\(tunnelState))"
        case let .disconnect(tunnelConnectionError):
            ".disconnect(\(String(describing: tunnelConnectionError))"
        case .cleanup:
            ".cleanup"
        }
    }
}
