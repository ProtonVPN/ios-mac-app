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
import IssueReporting
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

    /// The current peer. Emits `nil` after a disconnect zeroes the region.
    public var observePeer: @Sendable () -> AsyncStream<CurrentPeer?> = { .finished }
    /// The live NetShield / traffic stats.
    public var observeStats: @Sendable () -> AsyncStream<LocalAgent.Stats?> = { .finished }
    /// The server-applied Local Agent features.
    public var observeFeatures: @Sendable () -> AsyncStream<AgentTunnelFeatures?> = { .finished }
    /// The extension's most-recent error payload.
    public var observeError: @Sendable () -> AsyncStream<IPCErrorPayload> = { .finished }

    /// Attaches the coalesced shared region and builds the channel views over it.
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

    private struct State {
        var channels: Channels?
        var nextSubscriberID = 0
        var subscribers: [Int: @Sendable (Channels) -> Void] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var channels: Channels? {
        state.withLock { $0.channels }
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
        // Swap in the new channels, then notify current subscribers outside the lock so they re-subscribe to them.
        let subscribers = state.withLock { state -> [@Sendable (Channels) -> Void] in
            state.channels = channels
            return Array(state.subscribers.values)
        }
        subscribers.forEach { $0(channels) }
    }

    /// Emits the current `Channels` (if a region is attached) and every subsequent (re)attach.
    private func channelsStream() -> AsyncStream<Channels> {
        AsyncStream { continuation in
            let (id, current) = state.withLock { state -> (Int, Channels?) in
                let id = state.nextSubscriberID
                state.nextSubscriberID += 1
                state.subscribers[id] = { continuation.yield($0) }
                return (id, state.channels)
            }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
            }
            if let current { continuation.yield(current) }
        }
    }

    /// Used to handle the extension lifecycle on macOS by re-attaching to the shared memory stream.
    func resubscribingStream<Value: Sendable>(
        _ makeStream: @escaping @Sendable (Channels) -> AsyncStream<Value>
    ) -> AsyncStream<Value> {
        AsyncStream { continuation in
            let pump = Task {
                var inner: Task<Void, Never>?
                for await channels in channelsStream() {
                    inner?.cancel()
                    inner = Task {
                        for await value in makeStream(channels) {
                            continuation.yield(value)
                        }
                    }
                }
                inner?.cancel()
            }
            continuation.onTermination = { _ in pump.cancel() }
        }
    }
}

extension RawChannels: DependencyKey {
    public static let liveValue: RawChannels = {
        let store = TunnelDataStore()

        #if !os(macOS)
            // macOS attaches its storage at connection time
            do {
                let containerURL = try FileManager.default.mainContainerURL
                try store.attach(IPCNotifications.SharedRegion(
                    fileURL: containerURL.appending(component: "tunnel_data"),
                    size: MemoryLayout<IPCTunnelData>.size
                ))
            } catch {
                // The app-group container should always be reachable via our entitlements; if it somehow isn't, fail
                // to initialize and report an issue. (This will result in all channel reads returning `0` values.)
                reportIssue("Failed to map the tunnel-data shared region: \(error)")
            }
        #endif

        return RawChannels(
            connectionData: { store.channels?.connectionData },
            localAgentStats: { store.channels?.localAgentStats },
            localAgentConnectionStats: { store.channels?.localAgentConnectionStats },
            localAgentError: { store.channels?.localAgentError },
            localAgentFeatures: { store.channels?.localAgentFeatures },
            observePeer: { store.resubscribingStream { $0.connectionData.currentPeerStream() } },
            observeStats: { store.resubscribingStream { $0.localAgentStats.statsStream() } },
            observeFeatures: { store.resubscribingStream { $0.localAgentFeatures.agentFeaturesStream() } },
            observeError: { store.resubscribingStream { $0.localAgentError.stream() } },
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
