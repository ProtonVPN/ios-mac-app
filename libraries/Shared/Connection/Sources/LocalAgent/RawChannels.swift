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

import Dependencies
import DependenciesMacros
import Foundation
import IPCErgonomics
import LocalAgentIPC
import os

/// Data source for channels coming from the extension.
@DependencyClient
public struct RawChannels: Sendable {
    public var connectionData: @Sendable () -> IPCNotifications.RawChannel<IPCConnectionDataPayload>?
    public var localAgentStats: @Sendable () -> IPCNotifications.RawChannel<IPCStatsPayload>?
    public var localAgentConnectionStats: @Sendable () -> IPCNotifications.RawChannel<IPCConnectionStatsPayload>?
    public var localAgentError: @Sendable () -> IPCNotifications.RawChannel<IPCErrorPayload>?
    public var localAgentFeatures: @Sendable () -> IPCNotifications.RawChannel<IPCAgentFeaturesPayload>?

    /// Attaches the coalesced shared region and builds the five channel views over it. iOS/tvOS call this once at
    /// startup with the file region, while macOS calls it with the `IOSurface` region once it's exchanged over XPC.
    public var attachRegion: @Sendable (IPCNotifications.SharedRegion) -> Void

    /// Clears every sub-region. Called on disconnect / tunnel start to clear out stale values.
    public var zeroAll: @Sendable () -> Void
}

private final class TunnelDataStore: Sendable {
    struct Channels: Sendable {
        let connectionData: IPCNotifications.RawChannel<IPCConnectionDataPayload>
        let localAgentStats: IPCNotifications.RawChannel<IPCStatsPayload>
        let localAgentConnectionStats: IPCNotifications.RawChannel<IPCConnectionStatsPayload>
        let localAgentError: IPCNotifications.RawChannel<IPCErrorPayload>
        let localAgentFeatures: IPCNotifications.RawChannel<IPCAgentFeaturesPayload>
    }

    private let storage = OSAllocatedUnfairLock<Channels?>(initialState: nil)

    var channels: Channels? {
        storage.withLock { $0 }
    }

    func attach(_ region: IPCNotifications.SharedRegion) {
        let channels = Channels(
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
        storage.withLock { $0 = channels }
    }
}

extension RawChannels: DependencyKey {
    public static let liveValue: RawChannels = {
        let store = TunnelDataStore()

        #if !os(macOS)
            // macOS attaches its storage at connection time
            let containerURL = try! FileManager.default.mainContainerURL
            store.attach(try! IPCNotifications.SharedRegion(
                fileURL: containerURL.appending(component: "tunnel_data"),
                size: MemoryLayout<IPCTunnelData>.size
            ))
        #endif

        return RawChannels(
            connectionData: { store.channels?.connectionData },
            localAgentStats: { store.channels?.localAgentStats },
            localAgentConnectionStats: { store.channels?.localAgentConnectionStats },
            localAgentError: { store.channels?.localAgentError },
            localAgentFeatures: { store.channels?.localAgentFeatures },
            attachRegion: { store.attach($0) },
            zeroAll: {
                guard let channels = store.channels else { return }
                channels.connectionData.zero()
                channels.localAgentStats.zero()
                channels.localAgentConnectionStats.zero()
                channels.localAgentError.zero()
                channels.localAgentFeatures.zero()
            }
        )
    }()
}

public extension DependencyValues {
    var rawChannels: RawChannels {
        get { self[RawChannels.self] }
        set { self[RawChannels.self] = newValue }
    }
}
