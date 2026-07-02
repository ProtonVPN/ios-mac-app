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

import ConcurrencyExtras
import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import IOSurface
import IPCErgonomics
import IPCDefinitions
import Logging
import os

/// The server-side of the memory-backed IPC channel. The extension should be the only process to write these values.
@DependencyClient
public struct ExtensionIPCServer: Sendable {
    public internal(set) var publishExtensionState: @Sendable (ExtensionState, UUID?) -> Void
    public internal(set) var publishStats: @Sendable (LocalAgent.Stats) -> Void
    public internal(set) var publishConnectionStats: @Sendable (LocalAgent.ConnectionStats) -> Void
    public internal(set) var publishFeatures: @Sendable (AgentTunnelFeatures) -> Void
    public internal(set) var publishError: @Sendable (any Error, UUID?) -> Void

    /// Mirrors whether the running tunnel currently has no peers.
    public internal(set) var setZeroPeerKillSwitchActive: @Sendable (Bool) -> Void

    /// Touches the `IPCConnectionData` similar to `publishExtensionState`, but only touches the UUID. This is how error
    /// "acking" works from the main app: the acknowledged error UUID is cleared from the error channel, and placed as
    /// the UUID of the IPCConnectionData to indicate that the error has been handled.
    public internal(set) var restampConnectionData: @Sendable (UUID) -> Void
    /// Clears the error region (and notifies), used once the app has acknowledged the last reported error.
    public internal(set) var clearError: @Sendable () -> Void

    /// Posts a ``TunnelCommand`` using ``notify_post``.
    public internal(set) var sendCommand: @Sendable (TunnelCommand) -> Void
    /// Zero every sub-region on disconnect and tunnel start to clear out stale values.
    public internal(set) var zeroAll: @Sendable () -> Void
    /// Attach the `IOSurface` this process writes into (macOS). Builds a fresh writer store on each (re)connection.
    /// No-op on iOS/tvOS, which write into a fixed file mapping built up front.
    public internal(set) var attachIOSurfaceBackedRegion: @Sendable (IOSurfaceRef) -> Void
}

extension ExtensionIPCServer: DependencyKey {
    public static let liveValue: ExtensionIPCServer = {
        // macOS starts empty and the store arrives/swaps via `attachIOSurfaceBackedRegion`, so its
        // lock holds an optional and skips writes until attached; iOS/tvOS map a fixed file up front, so the store is
        // always present and the lock is non-optional.
        #if os(macOS)
            let current = OSAllocatedUnfairLock<TunnelDataStore<WriterRole, IOSurfaceBackedRegion>?>(initialState: nil)
            let withStore: @Sendable (@Sendable (TunnelDataStore<WriterRole, IOSurfaceBackedRegion>) -> Void) -> Void = { body in
                current.withLock { store in
                    store.map(body)
                }
            }
        #else
            let current = OSAllocatedUnfairLock<TunnelDataStore<WriterRole, FileBackedRegion>>(initialState: .live())
            let withStore: @Sendable (@Sendable (TunnelDataStore<WriterRole, FileBackedRegion>) -> Void) -> Void = { body in
                current.withLock { body($0) }
            }
        #endif

        return ExtensionIPCServer(
            publishExtensionState: { connectionState, uuid in
                withStore { $0.channels.connectionData.mutate { $0 = IPCConnectionDataPayload(connectionState, id: uuid) } }
            },
            publishStats: { stats in
                withStore { $0.channels.localAgentStats.mutate { $0 = IPCStatsPayload(stats) } }
            },
            publishConnectionStats: { stats in
                withStore { $0.channels.localAgentConnectionStats.mutate { $0 = IPCConnectionStatsPayload(stats) } }
            },
            publishFeatures: { features in
                withStore { $0.channels.localAgentFeatures.mutate { $0 = IPCAgentFeaturesPayload(features) } }
            },
            publishError: { error, requestId in
                withStore { $0.channels.localAgentError.mutate { $0 = IPCErrorPayload(error, requestId: requestId) } }
            },
            setZeroPeerKillSwitchActive: { active in
                withStore { $0.channels.tunnelStatus.setZeroPeerKillSwitchActive(active) }
            },
            restampConnectionData: { requestId in
                withStore { $0.channels.connectionData.mutate { $0.requestId = requestId } }
            },
            clearError: { withStore { $0.channels.localAgentError.zero() } },
            sendCommand: { command in
                IPCNotifications.postRawState(.tunnelCmd, state: UInt64(command.rawValue))
            },
            zeroAll: {
                withStore { store in
                    store.channels.connectionData.zero()
                    store.channels.localAgentStats.zero()
                    store.channels.localAgentConnectionStats.zero()
                    store.channels.localAgentError.zero()
                    store.channels.localAgentFeatures.zero()
                    store.channels.tunnelStatus.zero()
                }
            },
            attachIOSurfaceBackedRegion: { surface in
                #if os(macOS)
                    current.withLock { $0 = .attached(to: surface) }
                #else
                    _ = surface
                    assertionFailure("This should be used only on macOS.")
                #endif
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
