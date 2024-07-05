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

public struct ExtensionFeature: Reducer, Sendable {
    @Dependency(\.tunnelManager) var tunnelManager

    public init() { }

    private enum CancelID { case observation }

    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
        case disconnected(TunnelConnectionError?)
        case disconnecting
        case connecting(LogicalServerInfo?)
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
        case disconnect
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

                return .merge(initial, observation)

            case .stopObservingStateChanges:
                return .cancel(id: CancelID.observation)

            case .connect(let intent):
                state = .connecting(.init(logicalID: intent.server.logical.id,
                                          serverID: intent.server.endpoint.id))
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
                state = .disconnecting
                return .none

            case .tunnelStatusChanged(.invalid):
                // TODO: error state? How can we recover? Remove and recreate manager?
                // TODO: log lastDisconnectionError
                state = .disconnected(nil)
                return .none

            case .tunnelStatusChanged(.disconnected):
                // TODO: Detect if we initiated the disconnection. If it was unexpected, log last disconnection error
                state = .disconnected(nil)
                return .none

            case .tunnelStatusChanged(.reasserting):
                // We don't need to model a reasserting status. Our tunnel should only briefly enter this state
                return .none

            case .disconnect:
                state = .disconnecting
                return .run { _ in try await tunnelManager.stopTunnel() }

            case .tunnelStartRequestFinished(.failure(let error)):
                log.error("Failed to start tunnel", category: .connection, metadata: ["error": "\(error)"])
                return .none

            case .connectionFinished(.failure(let error)):
                state = .disconnected(.unknownServer)
                return .send(.disconnect)

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
