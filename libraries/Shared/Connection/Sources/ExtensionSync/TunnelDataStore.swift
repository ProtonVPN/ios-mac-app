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
import IPCDefinitions
@_spi(Internals) import IPCErgonomics
import os
#if os(macOS)
    import IOSurface
#endif

/// Commands sent by the extension, representing a single ping that indicate an action should be taken.
public enum TunnelCommand: Int, Sendable, CaseIterable {
    /// The extension needs a fresh API session; the app should fork its own and send it back as a provider message.
    case forkSelectorRequest = 1
}

/// Manages unidirectional communication channels for tunnel data, providing access to data streams through a shared
/// memory-mapped buffer. The store maintains a single mapping of the entire `IPCTunnelData` buffer and exposes
/// individual ``IPCNotifications/RawChannel`` views for each field. All channels emit the same `.tunnelData`
/// notification when updated, and sequence locks are used to detect which regions have changed as well as protect
/// against torn reads.
///
/// Since the backing storage of the memory region being written to can change due to the daemon and device lifecycles,
/// the extension process announces the identity of the region (file inode on App Store builds, IOSurface ID on
/// externally-distributed apps) through the value announced in the `.tunnelData` notify message. Clients keep track of
/// this value and re-attach their mappings when they detect that it has changed.
final class TunnelDataStore<Role, Backing: RegionBacking & ~Copyable>: Sendable {
    struct Channels: ~Copyable, Sendable {
        let connectionData: IPCNotifications.RawChannel<IPCConnectionDataPayload, Role, Backing>
        let localAgentStats: IPCNotifications.RawChannel<IPCStatsPayload, Role, Backing>
        let localAgentConnectionStats: IPCNotifications.RawChannel<IPCConnectionStatsPayload, Role, Backing>
        let localAgentError: IPCNotifications.RawChannel<IPCErrorPayload, Role, Backing>
        let localAgentFeatures: IPCNotifications.RawChannel<IPCAgentFeaturesPayload, Role, Backing>
        let packetCapture: IPCNotifications.RawChannel<IPCPacketCapturePayload, Role, Backing>
    }

    let channels: Channels
    private let region: IPCNotifications.SharedRegion<Backing>

    /// The identity the writer announces over the `.tunnelData` notify state.
    var regionID: UInt64 {
        region.backing.regionID
    }

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
            packetCapture: Self.channel(from: region, for: \.packet_capture, resultingType: IPCPacketCapturePayload.self)
        )
    }
}

#if os(macOS)
    extension TunnelDataStore where Backing == IOSurfaceBackedRegion {
        // Ideally we wouldn't need this to expose this, but we're supporting old OSes
        var surface: IOSurfaceRef {
            region.backing.ioSurface
        }

        /// Identifies the surface this store reads or writes, so both sides can compare mappings.
        var surfaceID: IOSurfaceID {
            region.backing.id
        }

        /// Build a store over the extension's IOSurface. Called from the connect flow when the surface arrives over
        /// XPC; a reconnection builds a fresh store and observers re-subscribe.
        static func attached(to surface: IOSurfaceRef) -> TunnelDataStore {
            TunnelDataStore(region: IPCNotifications.SharedRegion(IOSurfaceBackedRegion(surface)))
        }
    }
#else

    /// Where the region file lives, created by the writer only.
    private var tunnelDataFileURL: URL {
        get throws(FileManager.NoContainerFoundError) {
            try FileManager.default.mainContainerURL.appending(component: "tunnel_data")
        }
    }

    extension TunnelDataStore where Role == WriterRole, Backing == FileBackedRegion {
        #if os(tvOS)
            /// tvOS has no lock states.
            private static var regionProtection: FileProtectionType {
                .completeUntilFirstUserAuthentication
            }
        #else
            /// Seals the payloads whenever the device is locked, while still letting the extension create and write the
            /// region in any lock state (Class B).
            private static var regionProtection: FileProtectionType {
                .completeUnlessOpen
            }
        #endif

        /// Replaces any previous region file and maps the new one for writing.
        static func createdForWriting() throws -> TunnelDataStore {
            let backing = try FileBackedRegion(
                creating: tunnelDataFileURL,
                size: MemoryLayout<IPCTunnelData>.size,
                protection: regionProtection
            )
            return TunnelDataStore(region: IPCNotifications.SharedRegion(backing))
        }
    }

    extension TunnelDataStore where Role == ReaderRole, Backing == ReadOnlyFileBackedRegion {
        /// Maps the file the extension most recently created, read-only. Throws when none exists or when inaccessible
        /// due to the device being locked.
        static func openedForReading() throws -> TunnelDataStore {
            let backing = try ReadOnlyFileBackedRegion(
                opening: tunnelDataFileURL,
                size: MemoryLayout<IPCTunnelData>.size
            )
            return TunnelDataStore(region: IPCNotifications.SharedRegion(backing))
        }
    }
#endif
