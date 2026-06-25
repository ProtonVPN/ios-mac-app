//
//  Created on 24/06/2026.
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

import Foundation
import IPCErgonomics
import IssueReporting
import LocalAgentIPC

/// Commands sent by the tunnel to the extension, representing a single ping that indicate an action should be taken.
public enum TunnelCommand: Int, Sendable, CaseIterable {
    /// The extension needs a fresh API session; the app should fork its own and send it back as a provider message.
    case forkSelectorRequest = 1
}

/// ``IPCNotifications/RawChannel``s live here for now. This object is the backing store for several unidirectional
/// channels coming from the extension.
final class TunnelDataStore<Role: RawChannelRole>: Sendable {
    struct Channels: Sendable {
        let connectionData: IPCNotifications.RawChannel<IPCConnectionDataPayload, Role>
        let localAgentStats: IPCNotifications.RawChannel<IPCStatsPayload, Role>
        let localAgentConnectionStats: IPCNotifications.RawChannel<IPCConnectionStatsPayload, Role>
        let localAgentError: IPCNotifications.RawChannel<IPCErrorPayload, Role>
        let localAgentFeatures: IPCNotifications.RawChannel<IPCAgentFeaturesPayload, Role>
    }

    private let region: IPCNotifications.SharedRegion

    let channels: Channels

    private init(region: IPCNotifications.SharedRegion) {
        self.region = region
        self.channels = Channels(
            connectionData: .init(
                notification: .tunnelData, region: region,
                regionOffset: MemoryLayout<IPCTunnelData>.offset(of: \.connection_data)!
            ),
            localAgentStats: .init(
                notification: .tunnelData, region: region,
                regionOffset: MemoryLayout<IPCTunnelData>.offset(of: \.stats)!
            ),
            localAgentConnectionStats: .init(
                notification: .tunnelData, region: region,
                regionOffset: MemoryLayout<IPCTunnelData>.offset(of: \.connection_stats)!
            ),
            localAgentError: .init(
                notification: .tunnelData, region: region,
                regionOffset: MemoryLayout<IPCTunnelData>.offset(of: \.error)!
            ),
            localAgentFeatures: .init(
                notification: .tunnelData, region: region,
                regionOffset: MemoryLayout<IPCTunnelData>.offset(of: \.agent_features)!
            )
        )
    }

    /// Swap in the backing memory carried by `region`. macOS calls this when the extension's IOSurface arrives, which
    /// happens on every VPN (re)connection.
    func attach(_ region: IPCNotifications.SharedRegion) {
        self.region.adopt(region)
    }

    /// The initial value for the data store. Initially empty on macOS, iOS and tvOS use the group container.
    static func live() -> TunnelDataStore {
        #if os(macOS)
            return TunnelDataStore(region: IPCNotifications.SharedRegion())
        #else
            do {
                let containerURL = try FileManager.default.mainContainerURL
                let region = try IPCNotifications.SharedRegion(
                    fileURL: containerURL.appending(component: "tunnel_data"),
                    size: MemoryLayout<IPCTunnelData>.size
                )
                return TunnelDataStore(region: region)
            } catch {
                preconditionFailure("Failed to map the tunnel-data shared region: \(error)")
            }
        #endif
    }
}
