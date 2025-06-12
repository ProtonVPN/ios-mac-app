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

import ComposableArchitecture
import Dependencies

import let CoreConnection.log
import struct CoreConnection.LogicalServerInfo
import ExtensionIPC

import Domain
import Ergonomics
import Strings

@available(iOS 16, *)
public struct ExtensionFeature: Reducer, Sendable {
    @Dependency(\.tunnelManager) var tunnelManager

    public init() {}

    private enum CancelID {
        case tunnelStart
        case observation
    }

    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
        case unknown // Initial tunnel state
        case disconnected(TunnelConnectionError?)
        case disconnecting(TunnelConnectionError?)
        case preparingConnection(LogicalServerInfo) // Preparing managers and requesting tunnel start
        case connecting(LogicalServerInfo?) // Tunnel has been launched
        case connected(TunnelConnectionResponse)
    }

    @CasePathable
    public enum Action: Sendable {
        case startObservingStateChanges
        case stopObservingStateChanges
        case connect(ServerConnectionIntent)
        case tunnelStartRequestFinished(Result<Bool, Error>)
        case connectionFinished(Result<TunnelConnectionResponse, Error>)
        case tunnelStatusChanged(NEVPNStatus)
        case disconnect(TunnelConnectionError?)
        case removeManagers
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
                    // TODO: make sure we are only subscribed to state changes for the active tunnel
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
                let logicalServerInfo = LogicalServerInfo(logicalServer: intent.server)
                state = .preparingConnection(logicalServerInfo)
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

            case let .connectionFinished(.success(connectionInfo)):
                // Tunnel has started, and responded with information about what logical and server it has connected to
                state = .connected(connectionInfo)
                return .none

            case .tunnelStatusChanged(.connecting):
                // We should be transitioning into this state from `.preparingConnection`
                // Let's try to propagate server info from this previous state.
                let existingServerInfo: LogicalServerInfo? = state.preparingConnection ?? nil
                state = .connecting(existingServerInfo)
                return .none

            case .tunnelStatusChanged(.connected):
                if state.is(\.connected) {
                    // When testing, we sometimes want to start off a test case with already `connected` state.
                    // But we need to subscribe to state changes, and `startObservingStateChanges` yields an initial
                    // value. We need to ignore it in this case. We could in the future remove this check by separating
                    // no longer yielding an initial value when subscribing to state changes, and instead only doing so
                    // on a separate `onLaunch` action.
                    // But it's fine to exit early here if we are already connected either way.
                    log.warning("Received tunnel connected status while already connected", category: .connection)
                    return .none
                }
                // When we receive this event, it means the extension has called the completion handler on
                // `PacketTunnelProvider`'s `startTunnel` method, so technically we are 'connected' at this point.
                // But before we can actually start (re)connecting local agent, we need to know the details of the
                // server we are connected to, fetched through `tunnelManager.connectedServer`

                // Don't reset server we are connecting to if it's already set
                state = .connecting(state.connecting ?? nil)

                return .run { send in
                    @Dependency(\.date) var date
                    let result = await Result { try await TunnelConnectionResponse(
                        logicalInfo: tunnelManager.connectedServer,
                        connectionDate: tunnelManager.session.connectedDate ?? date.now
                    ) }
                    return await send(.connectionFinished(result))
                }

            case .tunnelStatusChanged(.disconnecting):
                let existingError = state.disconnecting ?? nil // Potential cause of disconnection
                state = .disconnecting(existingError)
                return .none

            case .tunnelStatusChanged(.invalid):
                // A notable scenario in which the tunnel state is invalid is before the user gives the app permission
                // to manage VPN configurations
                state = .disconnected(nil)
                return logLastDisconnectEffect

            case .tunnelStatusChanged(.disconnected):
                let existingError = state.disconnecting ?? nil // Potential cause of disconnection
                state = .disconnected(existingError)
                return .none

            case .tunnelStatusChanged(.reasserting):
                // We don't need to model a reasserting status. Our tunnel should only briefly enter this state
                return .none

            case let .disconnect(error):
                if case .preparingConnection = state {
                    // The tunnel has not yet been started, so we can transition straight into `.disconnected`.
                    state = .disconnected(error)
                    return .cancel(id: CancelID.tunnelStart)
                }
                if state.shouldTransitionToDisconnecting {
                    state = .disconnecting(error)
                }
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
                return logLastDisconnectEffect

            case let .connectionFinished(.failure(error)):
                log.error("Tunnel failed to connect", category: .connection, metadata: ["error": "\(error)"])
                return .send(.disconnect(.unknownServer))

            case let .tunnelStatusChanged(unknownFutureStatus):
                log.error("Unknown tunnel status", category: .connection, metadata: ["error": "\(unknownFutureStatus)"])
                assertionFailure("Unknown tunnel status \(unknownFutureStatus)")
                return .none

            case .removeManagers:
                return .run { _ in
                    try await tunnelManager.removeManagers()
                } catch: { error, _ in
                    log.assertionFailure("Failed to remove managers: \(error)")
                }
            }
        }
    }

    private var logLastDisconnectEffect: Effect<Action> {
        .run { _ in
            if let error = try await tunnelManager.session.fetchLastDisconnectError() {
                log.error("Last disconnect error: \(error)", category: .connection)
            }
        } catch: { error, _ in
            log.error("Failed to determine last disconnect error \(error)", category: .connection)
        }
    }
}

private extension ExtensionFeature.State {
    /// In case of an explicit disconnect action received within the Reducer, we should transition to `.disconnecting`
    /// only when it makes sense.
    /// Especially, we want to avoid transitioning to `.disconnecting` when we were already `.disconnected`.
    var shouldTransitionToDisconnecting: Bool {
        switch self {
        case .preparingConnection, .connecting, .connected:
            true
        case .unknown, .disconnecting, .disconnected:
            false
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

public struct TunnelConnectionResponse: Equatable, Sendable {
    public let logicalInfo: LogicalServerInfo
    public let connectionDate: Date

    package init(logicalInfo: LogicalServerInfo, connectionDate: Date) {
        self.logicalInfo = logicalInfo
        self.connectionDate = connectionDate
    }
}

extension ExtensionFeature.State {
    /// The network extension process has a mind of its own. If we've previously invoked `startTunnel`, and we invoke
    /// `stopTunnel` before waiting for the extension to actually transition to `.connected` or `.disconnected`, we
    /// may get unexpected results. For now, the parent feature should delay disconnection until this feature is ready
    /// to accept such events.
    package var isInteractionAllowed: Bool {
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

        case .unknown, .preparingConnection, .disconnecting:
            false
        }
    }
}
