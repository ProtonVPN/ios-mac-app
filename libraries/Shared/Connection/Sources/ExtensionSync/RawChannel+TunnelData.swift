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
import Logging

private let log: Logging.Logger = .init(label: "ProtonVPN.TunnelData.logger")

// Typed accessors over the tunnel-data channels. Each reads the raw C payload and returns the Swift struct that wraps
// it. `ExtensionIPCClient` builds the matching streams.

public extension IPCNotifications.RawChannel where Payload == IPCConnectionDataPayload, Role == ReaderRole, Backing: ~Copyable {
    func currentExtensionState() -> ExtensionStateSnapshot {
        if let payload = readOrLog("extension state") {
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
}

public extension IPCNotifications.RawChannel where Payload == IPCStatsPayload, Role == ReaderRole, Backing: ~Copyable {
    func stats() -> LocalAgent.Stats? {
        readOrLog("stats").flatMap(\.localAgentStats)
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCAgentFeaturesPayload, Role == ReaderRole, Backing: ~Copyable {
    /// The server-applied features, or `nil` until the extension has published them.
    func agentFeatures() -> AgentTunnelFeatures? {
        readOrLog("agent features")?.agentFeatures
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCPacketCapturePayload, Role == ReaderRole, Backing: ~Copyable {
    func packetCaptureReport() -> PacketCaptureReport {
        readOrLog("packet capture report")?.packetCaptureReport ?? .cleared
    }
}

public extension IPCNotifications.RawChannel where Payload == IPCErrorPayload, Role == ReaderRole, Backing: ~Copyable {
    func currentExtensionError() -> ExtensionError? {
        readOrLog("extension error")?.extensionError
    }
}

private extension IPCNotifications.RawChannel where Role == ReaderRole, Backing: ~Copyable {
    /// Reads the channel, logging a failure instead of throwing it. The accessors above feed the non-throwing getters
    /// on `ExtensionIPCClient`, so the log is the only place a failed read shows up.
    func readOrLog(_ description: StaticString) -> Payload? {
        do {
            return try read()
        } catch {
            log.error("Could not read \(description) from the tunnel-data channel: \(error)")
            return nil
        }
    }
}
