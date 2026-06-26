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

import ConcurrencyExtras
import CoreConnection
import Domain
import Foundation
import IPCErgonomics
import LocalAgentIPC

// Typed accessors over the live tunnel-data channels. Each exposes the Swift struct that wraps the raw C payload as
// a getter + an `AsyncStream`.

public extension IPCNotifications.RawChannel where Payload == IPCConnectionDataPayload, Role == IPCNotifications.Reader {
    func currentExtensionState() -> (ExtensionState, UUID?) {
        if let payload = try? read() {
            (payload.extensionState, payload.requestId)
        } else {
            (.disconnected(reason: .unset), nil)
        }
    }

    func extensionStateStream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<(state: ExtensionState, requestId: UUID?)> {
        stream(reconcileOn: resumeSignal) { payload in
            (payload.extensionState, payload.requestId)
        }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCStatsPayload, Role == IPCNotifications.Reader {
    func stats() -> LocalAgent.Stats? {
        (try? read()).flatMap(\.localAgentStats)
    }

    func statsStream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<LocalAgent.Stats?> {
        stream(reconcileOn: resumeSignal) { $0.localAgentStats }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCConnectionStatsPayload, Role == IPCNotifications.Reader {
    func connectionStats() -> LocalAgent.ConnectionStats? {
        (try? read()).flatMap(\.localAgentConnectionStats)
    }

    func connectionStatsStream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<LocalAgent.ConnectionStats?> {
        stream(reconcileOn: resumeSignal) { $0.localAgentConnectionStats }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCAgentFeaturesPayload, Role == IPCNotifications.Reader {
    /// The server-applied features, or `nil` until the extension has published them (or after a disconnect zeroes the region).
    func agentFeatures() -> AgentTunnelFeatures? {
        (try? read())?.agentFeatures
    }

    func agentFeaturesStream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<AgentTunnelFeatures?> {
        stream(reconcileOn: resumeSignal) { $0.agentFeatures }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCErrorPayload, Role == IPCNotifications.Reader {
    /// The extension's most-recent reported error, or `nil` if the value is empty.
    func errorStream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<(ExtensionError?, UUID?)> {
        stream(reconcileOn: resumeSignal) { ($0.extensionError, UUID(uuid: $0.config_id)) }
    }
}
