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

import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import struct Domain.ServerConnectionIntent
import struct ConnectionFoundations.LogicalServerInfo
import ExtensionIPC
import let ConnectionFoundations.log

@available(iOS 16, *)
public struct ExtensionFeature: Reducer, Sendable {
    @Dependency(\.tunnelManager) var tunnelManager

    public init() { }

    private enum CancelID { case observation }

    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
        case disconnected(TunnelConnectionError?)
        case disconnecting(TunnelConnectionError?)
        case preparingConnection(LogicalServerInfo) // Preparing managers and requesting tunnel start
        case connecting(LogicalServerInfo?) // Tunnel has been launched
        case connected(LogicalServerInfo)
    }

    @CasePathable
    public enum Action: Sendable {
        case startObservingStateChanges
        case stopObservingStateChanges
        case connect(ServerConnectionIntent)
        case tunnelStartRequestFinished(Result<Void, Error>)
        case connectionFinished(Result<LogicalServerInfo, Error>)
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
                    let status = try await self.tunnelManager.status
                    return await send(.tunnelStatusChanged(status))
                }
                let observation: Effect<ExtensionFeature.Action> = .run { send in
                    // TODO: make sure we are only subscribed to state changes for the active tunnel
                    for await status in try await self.tunnelManager.statusStream {
                        await send(.tunnelStatusChanged(status))
                    }
                }
                    .cancellable(id: CancelID.observation)

                // These effects must not be executed concurrently until we make `PacketTunnelManager` concurrency safe.
                // Doing so has the potential to create a duplicate set of `NETunnelProviderManager` and `NEVPNSession`
                // objects, with us potentially observing the status changes of one pair, while sending `startTunnel`
                // and `stopTunnel` commands to the other, resulting in failure to connect.
                return .concatenate(initial, observation)

            case .stopObservingStateChanges:
                return .cancel(id: CancelID.observation)

            case .connect(let intent):
                let logicalServerInfo = LogicalServerInfo(logicalServer: intent.server)
                state = .preparingConnection(logicalServerInfo)
                return .run { send in
                    await send(.tunnelStartRequestFinished(Result {
                        try await tunnelManager.startTunnel(with: intent)
                    }))
                }

            case .tunnelStartRequestFinished(.success):
                // Tunnel has started, but we may still need to wait for connection to be established
                return .none

            case .connectionFinished(.success(let logicalServerInfo)):
                // Tunnel has started, and responded with information about what logical and server it has connected to
                state = .connected(logicalServerInfo)
                return .none

            case .tunnelStatusChanged(.connecting):
                // We should be transitioning into this state from `.preparingConnection`
                // Let's try to propagate server info from this previous state.
                let existingServerInfo: LogicalServerInfo? = state.preparingConnection ?? nil
                state = .connecting(existingServerInfo)
                return .none

            case .tunnelStatusChanged(.connected):
                // When we receive this event, it means the extension has called the completion handler on
                // `PacketTunnelProvider`'s `startTunnel` method, so technically we are 'connected' at this point.
                // But before we can actually start (re)connecting local agent, we need to know the details of the
                // server we are connected to, fetched through `tunnelManager.connectedServer`

                // Don't reset server we are connecting to if it's already set
                state = .connecting(state.connecting ?? nil)

                return .run { send in
                    await send(.connectionFinished(Result {
                        try await tunnelManager.connectedServer
                    }))
                }

            case .tunnelStatusChanged(.disconnecting):
                let existingError = state.disconnecting ?? nil // Potential cause of disconnection
                state = .disconnecting(existingError)
                return .none

            case .tunnelStatusChanged(.invalid):
                // A notable scenario in which the tunnel state is invalid is before the user gives the app permission
                // to manage VPN configurations
                state = .disconnected(nil)
                return .none

            case .tunnelStatusChanged(.disconnected):
                let existingError = state.disconnecting ?? nil // Potential cause of disconnection
                state = .disconnected(existingError)
                return .none

            case .tunnelStatusChanged(.reasserting):
                // We don't need to model a reasserting status. Our tunnel should only briefly enter this state
                return .none

            case .disconnect(let error):
                if case .preparingConnection = state {
                    // The tunnel has not yet been started, so we can transition straight into `.disconnected`.
                    state = .disconnected(error)
                    return .none
                }
                if case .disconnecting = state { return .none }
                state = .disconnecting(error)
                return .run {
                    _ in try await tunnelManager.stopTunnel()
                } catch: { error, _ in
                    log.assertionFailure("Failed to stop tunnel: \(error)")
                }

            case .tunnelStartRequestFinished(.failure(let error)):
                // Start request failed, so there's no need to disconnect
                state = .disconnected(.tunnelStartFailed(error))
                return .none

            case .connectionFinished(.failure(let error)):
                log.error("Tunnel failed to connect", category: .connection, metadata: ["error": "\(error)"])
                return .send(.disconnect(.unknownServer))

            case .tunnelStatusChanged(let unknownFutureStatus):
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
}

@CasePathable
public enum TunnelConnectionError: Error, Equatable {
    case tunnelStartFailed(Error)
    case unknownServer

    public static func == (lhs: TunnelConnectionError, rhs: TunnelConnectionError) -> Bool {
        switch (lhs, rhs) {
        case (.tunnelStartFailed, .tunnelStartFailed):
            return true

        case (.unknownServer, .unknownServer):
            return true

        default:
            return false
        }
    }
}
