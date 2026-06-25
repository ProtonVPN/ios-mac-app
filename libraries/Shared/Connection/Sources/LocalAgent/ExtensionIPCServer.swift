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

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import IPCErgonomics
import LocalAgentIPC

/// The server-side of the memory-backed IPC channel. The extension should be the only process to write these values.
@DependencyClient
public struct ExtensionIPCServer: Sendable {
    public var publishExtensionState: @Sendable (ExtensionState) -> Void
    public var publishStats: @Sendable (LocalAgent.Stats) -> Void
    public var publishConnectionStats: @Sendable (LocalAgent.ConnectionStats) -> Void
    public var publishFeatures: @Sendable (AgentTunnelFeatures) -> Void
    public var publishError: @Sendable (any Error, UUID?) -> Void

    /// Posts a ``TunnelCommand`` using ``notify_post``.
    public var sendCommand: @Sendable (TunnelCommand) -> Void
    /// Attach to the region this process writes into - file-backed `mmap` on iOS/tvOS, or ``IOSurface`` on macOS.
    public var attachRegion: @Sendable (IPCNotifications.SharedRegion) -> Void
    /// Zero every sub-region on disconnect and tunnel start to clear out stale values.
    public var zeroAll: @Sendable () -> Void
}

extension ExtensionIPCServer: DependencyKey {
    public static let liveValue: ExtensionIPCServer = {
        let store = TunnelDataStore<IPCNotifications.Writer>.live()
        return ExtensionIPCServer(
            publishExtensionState: { connectionState in store.channels.connectionData.mutate { $0 = IPCConnectionDataPayload(connectionState) } },
            publishStats: { stats in store.channels.localAgentStats.mutate { $0 = IPCStatsPayload(stats) } },
            publishConnectionStats: { stats in
                store.channels.localAgentConnectionStats.mutate { $0 = IPCConnectionStatsPayload(stats) }
            },
            publishFeatures: { features in store.channels.localAgentFeatures.mutate { $0 = IPCAgentFeaturesPayload(features) } },
            publishError: { error, requestId in store.channels.localAgentError.mutate { $0 = IPCErrorPayload(error, requestId: requestId) } },
            sendCommand: { command in
                IPCNotifications.postRawState(.tunnelCmd, state: UInt64(command.rawValue))
            },
            attachRegion: { store.attach($0) },
            zeroAll: {
                store.channels.connectionData.zero()
                store.channels.localAgentStats.zero()
                store.channels.localAgentConnectionStats.zero()
                store.channels.localAgentError.zero()
                store.channels.localAgentFeatures.zero()
            }
        )
    }()
}

public extension DependencyValues {
    var extensionIPCServer: ExtensionIPCServer {
        get { self[ExtensionIPCServer.self] }
        set { self[ExtensionIPCServer.self] = newValue }
    }
}
