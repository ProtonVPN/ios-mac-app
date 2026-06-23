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
import os

/// Sent/received using the `tunnelCmd` notification, with the command value set as the notify token.
public enum TunnelCommand: Int, Sendable, CaseIterable {
    /// App should fork its API session and send a session selector as a provider message.
    case forkSelectorRequest = 1
}

/// DataStore object that represents the memory region backing all of the different ``RawChannel``s in the app.
final class TunnelDataStore: Sendable {
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
        // If for whatever reason theshe return `nil`, we probably have bigger problems to worry about
        guard
            let connectionDataOffset = MemoryLayout<IPCTunnelData>.offset(of: \.connection_data),
            let statsOffset = MemoryLayout<IPCTunnelData>.offset(of: \.stats),
            let connectionStatsOffset = MemoryLayout<IPCTunnelData>.offset(of: \.connection_stats),
            let errorOffset = MemoryLayout<IPCTunnelData>.offset(of: \.error),
            let agentFeaturesOffset = MemoryLayout<IPCTunnelData>.offset(of: \.agent_features)
        else {
            reportIssue("IPCTunnelData sub-region offsets are not computable; live tunnel data will be unavailable")
            return
        }
        let channels = Channels(
            connectionData: .init(notification: .tunnelData, region: region, regionOffset: connectionDataOffset),
            localAgentStats: .init(notification: .tunnelData, region: region, regionOffset: statsOffset),
            localAgentConnectionStats: .init(notification: .tunnelData, region: region, regionOffset: connectionStatsOffset),
            localAgentError: .init(notification: .tunnelData, region: region, regionOffset: errorOffset),
            localAgentFeatures: .init(notification: .tunnelData, region: region, regionOffset: agentFeaturesOffset)
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

    /// Listens to a ``RawChannel`` stream in a way that survives the region re-attaching if the app reconnects.
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

    /// Create a data store object, attaching immediately to the file-backed mmap region if on iOS/tvOS. macOS will
    /// attach later on when it checks in with the extension.
    static func live() -> TunnelDataStore {
        let store = TunnelDataStore()
        #if !os(macOS)
            do {
                let containerURL = try FileManager.default.mainContainerURL
                try store.attach(IPCNotifications.SharedRegion(
                    fileURL: containerURL.appending(component: "tunnel_data"),
                    size: MemoryLayout<IPCTunnelData>.size
                ))
            } catch {
                // The app-group container should always be reachable via our entitlements. Otherwise, report an issue.
                // Release apps should simply fail to connect here.
                reportIssue("Failed to map the tunnel-data shared region: \(error)")
            }
        #endif
        return store
    }
}
