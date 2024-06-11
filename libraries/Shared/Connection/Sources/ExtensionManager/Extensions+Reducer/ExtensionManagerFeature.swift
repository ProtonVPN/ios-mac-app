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

import struct Domain.VPNServer
import struct Domain.VPNConnectionFeatures
import ExtensionIPC
import let ConnectionFoundations.log

public struct ExtensionFeature: Reducer, Sendable {
    @Dependency(\.tunnelManager) var tunnelManager

    public init() { }

    private enum CancelID { case observation }

    @CasePathable
    public enum State: Equatable, Sendable {
        case disconnected
        case disconnecting
        case connecting(VPNServer, VPNConnectionFeatures)
        case connected
    }

    @CasePathable
    public enum Action: Sendable {
        case startObservingStateChanges
        case stopObservingStateChanges
        case connect(VPNServer, VPNConnectionFeatures)
        case tunnelStartRequestFinished(Result<VPNSession, Error>)
        case tunnelStatusChanged(NEVPNStatus)
        case disconnect
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startObservingStateChanges:
                // Subscribe to state changes
                let initial: Effect<ExtensionFeature.Action> = .run { send in
                    let status = try await self.tunnelManager.session.status
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

            case .connect(let server, let features):
                state = .connecting(server, features)
                return .run { send in
                    await send(.tunnelStartRequestFinished(Result {
                        try await tunnelManager.startTunnel(to: server)
                    }))
                }

            case .tunnelStartRequestFinished(.failure(let error)):
                log.error("Failed to start tunnel", category: .connection, metadata: ["error": "\(error)"])
                return .none

            case .tunnelStartRequestFinished(.success(let session)):
                return .none

            case .tunnelStatusChanged(.connecting):
                return .none

            case .tunnelStatusChanged(.connected):
                state = .connected
                return .none

            case .tunnelStatusChanged(.disconnecting):
                state = .disconnecting
                return .none

            case .tunnelStatusChanged(.invalid):
                // TODO: error state? How can we recover? Remove and recreate manager?
                // TODO: log lastDisconnectionError
                return .none

            case .tunnelStatusChanged(.disconnected):
                state = .disconnected
                // TODO: Detect if we initiated disconnection, or someone else. Log last disconnection error
                return .none

            case .tunnelStatusChanged(.reasserting):
                // We don't need to model a reasserting status. Our tunnel should only briefly enter this state
                return .none

            case .disconnect:
                state = .disconnecting
                return .run { _ in try await tunnelManager.stopTunnel() }

            case .tunnelStatusChanged(let unknownFutureStatus):
                log.error("Unknown tunnel status", category: .connection, metadata: ["error": "\(unknownFutureStatus)"])
                assertionFailure("Unknown tunnel status \(unknownFutureStatus)")
                return .none
            }
        }
    }
}
