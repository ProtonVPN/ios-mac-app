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
    public private(set) var publishExtensionState: @Sendable (ExtensionState, UUID?) -> Void
    public private(set) var publishStats: @Sendable (LocalAgent.Stats) -> Void
    public private(set) var publishConnectionStats: @Sendable (LocalAgent.ConnectionStats) -> Void
    public private(set) var publishFeatures: @Sendable (AgentTunnelFeatures) -> Void
    public private(set) var publishError: @Sendable (any Error, UUID?) -> Void

    /// Touches the `IPCConnectionData` similar to `publishExtensionState`, but only touches the UUID. This is how error
    /// "acking" works from the main app: the acknowledged error UUID is cleared from the error channel, and placed as
    /// the UUID of the IPCConnectionData to indicate that the error has been handled.
    public private(set) var restampConnectionData: @Sendable (UUID) -> Void
    /// Clears the error region (and notifies), used once the app has acknowledged the last reported error.
    public private(set) var clearError: @Sendable () -> Void

    /// Posts a ``TunnelCommand`` using ``notify_post``.
    public private(set) var sendCommand: @Sendable (TunnelCommand) -> Void
    /// Attach to the region this process writes into - file-backed `mmap` on iOS/tvOS, or ``IOSurface`` on macOS.
    public private(set) var attachRegion: @Sendable (IPCNotifications.SharedRegion) -> Void
    /// Zero every sub-region on disconnect and tunnel start to clear out stale values.
    public private(set) var zeroAll: @Sendable () -> Void
}

extension ExtensionIPCServer: DependencyKey {
    public static let liveValue: ExtensionIPCServer = {
        let store = TunnelDataStore<IPCNotifications.Writer>.live()
        return ExtensionIPCServer(
            publishExtensionState: { connectionState, uuid in store.channels.connectionData.mutate { $0 = IPCConnectionDataPayload(connectionState, id: uuid) } },
            publishStats: { stats in store.channels.localAgentStats.mutate { $0 = IPCStatsPayload(stats) } },
            publishConnectionStats: { stats in
                store.channels.localAgentConnectionStats.mutate { $0 = IPCConnectionStatsPayload(stats) }
            },
            publishFeatures: { features in store.channels.localAgentFeatures.mutate { $0 = IPCAgentFeaturesPayload(features) } },
            publishError: { error, requestId in store.channels.localAgentError.mutate { $0 = IPCErrorPayload(error, requestId: requestId) } },
            restampConnectionData: { requestId in store.channels.connectionData.mutate { $0.requestId = requestId } },
            clearError: { store.channels.localAgentError.zero() },
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
