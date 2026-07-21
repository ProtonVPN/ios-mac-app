//
//  Created on 25/06/2026.
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

import Domain
import Foundation
import IPCDefinitions

/// Loosely mirrors the `ConnectionState` enum in `protun`.
public enum ExtensionState: Sendable, Equatable {
    case disconnected(reason: IPCConnectionDisconnectReason)
    case connecting(peerID: String?, waitReason: IPCConnectionPeerWaitReason)
    case connectingToLocalAgent(peerID: String?, waitReason: IPCConnectionAgentWaitReason, jail: IPCConnectionAgentJailReason)
    case connected(CurrentPeer)
}

public struct ExtensionStateSnapshot: Sendable, Equatable {
    public let state: ExtensionState
    public let requestId: UUID?

    public init(state: ExtensionState, requestId: UUID?) {
        self.state = state
        self.requestId = requestId
    }
}

extension ExtensionState {
    public var peerID: String? {
        switch self {
        case .disconnected: nil
        case let .connected(peer): peer.peerID
        case let .connecting(peerID, _): peerID
        case let .connectingToLocalAgent(peerID, _, _): peerID
        }
    }

    /// Translates the current connection state to a raw int value.
    var connectionState: IPCConnectionState {
        switch self {
        case .disconnected: .disconnected
        case .connecting: .connecting
        case .connectingToLocalAgent: .connectingToLocalAgent
        case .connected: .connected
        }
    }

    /// Reassemble the state from the payload's bytes.
    init(_ payload: IPCConnectionDataPayload) {
        let peerID = payload.peerID.isEmpty ? nil : payload.peerID
        switch payload.connectionState {
        case .disconnected:
            self = .disconnected(reason: IPCConnectionDisconnectReason(rawValue: payload.reason) ?? .unset)
        case .connecting:
            self = .connecting(
                peerID: peerID,
                waitReason: IPCConnectionPeerWaitReason(rawValue: payload.reason) ?? .unset
            )
        case .connectingToLocalAgent:
            self = .connectingToLocalAgent(
                peerID: peerID,
                waitReason: IPCConnectionAgentWaitReason(rawValue: payload.reason) ?? .unset,
                jail: IPCConnectionAgentJailReason(rawValue: payload.context) ?? .unset
            )
        case .connected:
            if let peer = payload.currentPeer {
                self = .connected(peer)
            } else {
                assertionFailure("Peer should be present for connected state")
                self = .connecting(peerID: peerID, waitReason: .unset)
            }
        @unknown default:
            self = .disconnected(reason: .unset)
        }
    }
}
