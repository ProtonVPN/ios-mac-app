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
@_spi(Internals) import IPCErgonomics
import IssueReporting
import IPCDefinitions
import os
#if os(macOS)
    import IOSurface
#endif

/// Commands sent by the tunnel to the extension, representing a single ping that indicate an action should be taken.
public enum TunnelCommand: Int, Sendable, CaseIterable {
    /// The extension needs a fresh API session; the app should fork its own and send it back as a provider message.
    case forkSelectorRequest = 1
}

/// Manages unidirectional communication channels for tunnel data, providing access to data streams
/// through a shared memory-mapped buffer. The store maintains a single mapping of the entire `IPCTunnelData` buffer
/// and exposes individual ``IPCNotifications/RawChannel`` views for each field
/// All channels emit the same `.tunnelData` notification when updated.
///
/// The implementation uses platform-specific strategies for accessing the shared buffer: iOS/tvOS establish a
/// persistent file mapping in ``live()``, while macOS waits for the extension's IOSurface to arrive via
/// ``attached(to:)`` during the connection handshake.
final class TunnelDataStore<Role, Backing: RegionBacking & ~Copyable>: Sendable {
    struct Channels: ~Copyable, Sendable {
        let connectionData: IPCNotifications.RawChannel<IPCConnectionDataPayload, Role, Backing>
        let localAgentStats: IPCNotifications.RawChannel<IPCStatsPayload, Role, Backing>
        let localAgentConnectionStats: IPCNotifications.RawChannel<IPCConnectionStatsPayload, Role, Backing>
        let localAgentError: IPCNotifications.RawChannel<IPCErrorPayload, Role, Backing>
        let localAgentFeatures: IPCNotifications.RawChannel<IPCAgentFeaturesPayload, Role, Backing>
        let tunnelStatus: IPCNotifications.RawChannel<IPCTunnelStatusPayload, Role, Backing>
    }

    let channels: Channels
    private let region: IPCNotifications.SharedRegion<Backing>

    private static func channel<T: BitwiseCopyable>(
        from region: IPCNotifications.SharedRegion<Backing>,
        for seqlockRegionKeyPath: KeyPath<IPCTunnelData, some Any>,
        resultingType _: T.Type
    ) -> IPCNotifications.RawChannel<T, Role, Backing> {
        let offset = MemoryLayout<IPCTunnelData>.offset(of: seqlockRegionKeyPath)!
        return .init(notification: .tunnelData, seqlockRegion: region.seqlockRegion(at: offset))
    }

    private init(region: IPCNotifications.SharedRegion<Backing>) {
        self.region = region
        self.channels = Channels(
            connectionData: Self.channel(from: region, for: \.connection_data, resultingType: IPCConnectionDataPayload.self),
            localAgentStats: Self.channel(from: region, for: \.stats, resultingType: IPCStatsPayload.self),
            localAgentConnectionStats: Self.channel(from: region, for: \.connection_stats, resultingType: IPCConnectionStatsPayload.self),
            localAgentError: Self.channel(from: region, for: \.error, resultingType: IPCErrorPayload.self),
            localAgentFeatures: Self.channel(from: region, for: \.agent_features, resultingType: IPCAgentFeaturesPayload.self),
            tunnelStatus: Self.channel(from: region, for: \.tunnel_status, resultingType: IPCTunnelStatusPayload.self)
        )
    }
}

#if os(macOS)
    extension TunnelDataStore where Backing == IOSurfaceBackedRegion {
        // Ideally we wouldn't need this to expose this, but we're supporting old OSes
        var surface: IOSurfaceRef {
            region.backing.ioSurface
        }

        /// Build a store over the extension's IOSurface. Called from the connect flow when the surface arrives over
        /// XPC; a reconnection builds a fresh store and observers re-subscribe.
        static func attached(to surface: IOSurfaceRef) -> TunnelDataStore {
            TunnelDataStore(region: IPCNotifications.SharedRegion(IOSurfaceBackedRegion(surface)))
        }
    }
#else

    extension TunnelDataStore where Backing == FileBackedRegion {
        /// Map the shared app group container up front. iOS and tvOS use a fixed file mapping for the lifetime of the
        /// store.
        static func live() -> TunnelDataStore {
            do {
                let containerURL = try FileManager.default.mainContainerURL
                let backing = try FileBackedRegion(
                    fileURL: containerURL.appending(component: "tunnel_data"),
                    size: MemoryLayout<IPCTunnelData>.size
                )
                return TunnelDataStore(region: IPCNotifications.SharedRegion(backing))
            } catch {
                preconditionFailure("Failed to map the tunnel-data shared region: \(error)")
            }
        }
    }
#endif
