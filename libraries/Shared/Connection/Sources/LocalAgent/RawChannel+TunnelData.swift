//
//  Created on 22/06/2026.
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

import CoreConnection
import Domain
import Foundation
import IPCErgonomics
import LocalAgentIPC

// Typed accessors over the live tunnel-data channels. Each exposes the Swift struct that wraps the raw C payload as
// a getter + an `AsyncStream`.

public extension IPCNotifications.RawChannel where Payload == IPCConnectionDataPayload {
    /// The current peer, or `nil` if none has been published yet.
    func currentPeer() -> CurrentPeer? {
        (try? read())?.currentPeer
    }

    func currentPeerStream() -> AsyncStream<CurrentPeer?> {
        stream { $0.currentPeer }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCStatsPayload {
    func stats() -> LocalAgent.Stats? {
        (try? read()).flatMap(\.localAgentStats)
    }

    func statsStream() -> AsyncStream<LocalAgent.Stats?> {
        stream { $0.localAgentStats }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCConnectionStatsPayload {
    func connectionStats() -> LocalAgent.ConnectionStats? {
        (try? read()).flatMap(\.localAgentConnectionStats)
    }

    func connectionStatsStream() -> AsyncStream<LocalAgent.ConnectionStats?> {
        stream { $0.localAgentConnectionStats }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCAgentFeaturesPayload {
    /// The server-applied features, or `nil` until the extension has published them (or after a disconnect zeroes the region).
    func agentFeatures() -> AgentTunnelFeatures? {
        (try? read())?.agentFeatures
    }

    func agentFeaturesStream() -> AsyncStream<AgentTunnelFeatures?> {
        stream { $0.agentFeatures }
    }
}
