//
//  Created on 18/02/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG && os(iOS)
    import Domain
    import Foundation
    import os.log

    enum MessageRouter {
        static func route(
            _ request: ProTUNMessage.Request,
            with provider: ProTUNPacketTunnelProvider
        ) async -> ProTUNMessage.Response {
            guard request.version <= ProTUNMessage.Version.current else {
                return .requestVersionMismatchResponse(from: request.version)
            }
            switch request.payload {
            case .ping:
                return .init(payload: .pong)
            case .getCurrentPeerID:
                return await handleGetCurrentPeerID(from: provider)
            }
        }
    }

    private extension MessageRouter {
        static func handleGetCurrentPeerID(from provider: ProTUNPacketTunnelProvider) async -> ProTUNMessage.Response {
            do {
                let currentState = try await provider.stateDelegate.state
                switch currentState {
                case let .connected(peer):
                    return .init(payload: .currentPeerID(.success(peer.peerId)))
                default:
                    Logger.provider.error("Received getCurrentPeerID but currently not connected")
                    return .init(payload: .currentPeerID(.failure(.init(failureReason: "Received getCurrentPeerID but currently not connected"))))
                }
            } catch {
                Logger.provider.error("Failed to retrieve ProTUN state")
                return .init(payload: .currentPeerID(.failure(.init(failureReason: "Failed to retrieve ProTUN state"))))
            }
        }
    }
#endif
