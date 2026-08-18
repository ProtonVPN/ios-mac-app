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
import IPCDefinitions
import IPCErgonomics

// Typed accessors over the live tunnel-data channels. Each exposes the Swift struct that wraps the raw C payload as
// a getter + an `AsyncStream`.

public extension IPCNotifications.RawChannel where Payload == IPCConnectionDataPayload, Role == ReaderRole, Backing: ~Copyable {
    func currentExtensionState() -> ExtensionStateSnapshot {
        if let payload = try? read() {
            ExtensionStateSnapshot(
                state: payload.extensionState,
                requestId: payload.requestId
            )
        } else {
            ExtensionStateSnapshot(
                state: .disconnected(reason: .unset),
                requestId: nil
            )
        }
    }

    func extensionStateStream(reconcileOn resumeSignals: AsyncStream<Void>...) -> AsyncStream<ExtensionStateSnapshot> {
        stream(reconcileOn: resumeSignals) { payload in
            ExtensionStateSnapshot(
                state: payload.extensionState,
                requestId: payload.requestId
            )
        }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCStatsPayload, Role == ReaderRole, Backing: ~Copyable {
    func stats() -> LocalAgent.Stats? {
        (try? read()).flatMap(\.localAgentStats)
    }

    func statsStream(reconcileOn resumeSignals: AsyncStream<Void>...) -> AsyncStream<LocalAgent.Stats?> {
        stream(reconcileOn: resumeSignals) { $0.localAgentStats }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCAgentFeaturesPayload, Role == ReaderRole, Backing: ~Copyable {
    /// The server-applied features, or `nil` until the extension has published them (or after a disconnect zeroes the region).
    func agentFeatures() -> AgentTunnelFeatures? {
        (try? read())?.agentFeatures
    }

    func agentFeaturesStream(reconcileOn resumeSignals: AsyncStream<Void>...) -> AsyncStream<AgentTunnelFeatures?> {
        stream(reconcileOn: resumeSignals) { $0.agentFeatures }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCPacketCapturePayload, Role == ReaderRole, Backing: ~Copyable {
    func packetCaptureReport() -> PacketCaptureReport {
        (try? read())?.packetCaptureReport ?? .cleared
    }

    func packetCaptureStream(reconcileOn resumeSignals: AsyncStream<Void>...) -> AsyncStream<PacketCaptureReport> {
        stream(reconcileOn: resumeSignals) { $0.packetCaptureReport }
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCErrorPayload, Role == ReaderRole, Backing: ~Copyable {
    func currentExtensionError() -> ExtensionError? {
        (try? read())?.extensionError
    }

    /// The extension's most-recent reported error, or `nil` if the value is empty.
    func errorStream(reconcileOn resumeSignals: AsyncStream<Void>...) -> AsyncStream<ExtensionError?> {
        stream(reconcileOn: resumeSignals) { $0.extensionError }
    }
}
