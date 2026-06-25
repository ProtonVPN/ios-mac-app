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
import Domain
import Foundation
import IPCErgonomics
import LocalAgentIPC

/// The platform "app became active" notification
private let appDidBecomeActiveNotification: Notification.Name = {
    #if os(macOS)
        Notification.Name("NSApplicationDidBecomeActiveNotification")
    #else
        Notification.Name("UIApplicationDidBecomeActiveNotification")
    #endif
}()

/// Notifies channels to check if the generation counter for their values have changed, and broadcast updates if so.
private func appBecameActiveTicks() -> AsyncStream<Void> {
    UncheckedSendable(
        NotificationCenter.default
            .notifications(named: appDidBecomeActiveNotification)
            .map { _ in () }
    )
    .eraseToStream()
}

/// Read-only channels for consuming updates to tunnel data from the extension.
@DependencyClient
public struct ExtensionIPCClient: Sendable {
    /// The current peer, or `nil` before the extension publishes one (or after a disconnect zeroes the region).
    public var currentPeer: @Sendable () -> CurrentPeer?
    /// The current NetShield / traffic stats, or `nil` before the extension has published any.
    public var currentStats: @Sendable () -> LocalAgent.Stats?
    /// The current server-applied Local Agent features, or `nil` before the extension has published any.
    public var currentFeatures: @Sendable () -> AgentTunnelFeatures?

    /// The current peer information.
    public var observePeer: @Sendable () -> AsyncStream<CurrentPeer?> = { .finished }
    /// The live NetShield / traffic stats.
    public var observeStats: @Sendable () -> AsyncStream<LocalAgent.Stats?> = { .finished }
    /// The server-applied Local Agent features.
    public var observeFeatures: @Sendable () -> AsyncStream<AgentTunnelFeatures?> = { .finished }
    /// The extension's most-recent reported error (`nil` when the slot is empty), decoded from the raw payload.
    public var observeError: @Sendable () -> AsyncStream<ExtensionError?> = { .finished }
    /// Commands the extension posts over the `.tunnelCmd` notification.
    public var observeCommands: @Sendable () -> AsyncStream<TunnelCommand> = { .finished }

    /// macOS: attach the `IOSurface` region received from the extension over XPC so reads/streams resolve against it.
    public var attachRegion: @Sendable (IPCNotifications.SharedRegion) -> Void
}

extension ExtensionIPCClient: DependencyKey {
    public static let liveValue: ExtensionIPCClient = {
        let store = TunnelDataStore<IPCNotifications.Reader>.live()
        return ExtensionIPCClient(
            currentPeer: { store.channels.connectionData.currentPeer() },
            currentStats: { store.channels.localAgentStats.stats() },
            currentFeatures: { store.channels.localAgentFeatures.agentFeatures() },
            observePeer: { store.channels.connectionData.currentPeerStream(reconcileOn: appBecameActiveTicks()) },
            observeStats: { store.channels.localAgentStats.statsStream(reconcileOn: appBecameActiveTicks()) },
            observeFeatures: { store.channels.localAgentFeatures.agentFeaturesStream(reconcileOn: appBecameActiveTicks()) },
            observeError: { store.channels.localAgentError.errorStream(reconcileOn: appBecameActiveTicks()) },
            observeCommands: {
                AsyncStream { continuation in
                    let token = IPCNotifications.observeRawState(.tunnelCmd) { state in
                        if let command = TunnelCommand(rawValue: Int(state)) {
                            continuation.yield(command)
                        }
                    }
                    let observation = token.observation()
                    continuation.onTermination = { _ in observation.cancel() }
                }
            },
            attachRegion: { store.attach($0) }
        )
    }()
}

public extension DependencyValues {
    var extensionIPC: ExtensionIPCClient {
        get { self[ExtensionIPCClient.self] }
        set { self[ExtensionIPCClient.self] = newValue }
    }
}
