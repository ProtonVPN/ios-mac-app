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

import Combine
import ConcurrencyExtras
import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import IOSurface
import IPCDefinitions
import IPCErgonomics
import Logging
import os
import Sharing

private let log: Logging.Logger = .init(label: "ProtonVPN.ExtensionIPCClient.logger")

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
    /// The current connection state according to ProTUN in the network extension.
    public package(set) var currentExtensionState: @Sendable () -> ExtensionStateSnapshot = {
        .init(state: .disconnected(reason: .unset), requestId: nil)
    }

    /// The current NetShield / traffic stats, or `nil` before the extension has published any.
    public package(set) var currentStats: @Sendable () -> LocalAgent.Stats?
    /// The current server-applied Local Agent features, or `nil` before the extension has published any.
    public package(set) var currentFeatures: @Sendable () -> AgentTunnelFeatures?
    /// The extension's most-recent reported error, or `nil` if it's empty.
    public package(set) var currentExtensionError: @Sendable () -> ExtensionError? = { nil }
    /// What ProTUN is doing with the declared packet capture. A cleared region reads as stopped.
    public package(set) var currentPacketCapture: @Sendable () -> PacketCaptureReport = { .cleared }

    /// The live connection state according to ProTUN in the network extension.
    public package(set) var observeExtensionState: @Sendable () -> AsyncStream<ExtensionStateSnapshot> = { .finished }
    /// The live NetShield / traffic stats.
    public package(set) var observeStats: @Sendable () -> AsyncStream<LocalAgent.Stats?> = { .finished }
    /// The server-applied Local Agent features.
    public package(set) var observeFeatures: @Sendable () -> AsyncStream<AgentTunnelFeatures?> = { .finished }
    /// The extension's most-recent reported error (`nil` when the slot is empty), decoded from the raw payload.
    public package(set) var observeError: @Sendable () -> AsyncStream<ExtensionError?> = { .finished }
    /// The live state of the declared packet capture.
    public package(set) var observePacketCapture: @Sendable () -> AsyncStream<PacketCaptureReport> = { .finished }
    /// Commands the extension posts over the `.tunnelCmd` notification.
    public package(set) var observeCommands: @Sendable () -> AsyncStream<TunnelCommand> = { .finished }

    /// Attach the `IOSurface` received from the extension over XPC (macOS).
    public var attachRegion: @Sendable (IOSurfaceRef) -> Void

    /// The identity of the region currently mapped, or `nil` when nothing is attached.
    public package(set) var currentRegionID: @Sendable () -> UInt64? = { nil }
}

extension ExtensionIPCClient: DependencyKey {
    /// The region the writer last announced.
    private static let region = AttachedRegion()

    #if !os(macOS)
        /// Remaps to the announced region when it changed. State 0 means nothing announced yet.
        private static func reattachIfNeeded() {
            let announced = IPCNotifications.getRawState(.tunnelData)
            guard announced != 0 else { return }
            do {
                try region.replace(when: { $0?.regionID != announced }) {
                    try ReaderStore.openedForReading()
                }
            } catch {
                log.error("Could not map announced tunnel-data region \(announced): \(error)")
            }
        }

        private static let attachLifetime: Task<Void, Never> = {
            let posts = IPCNotifications.ticks(.tunnelData)
            reattachIfNeeded()
            return Task {
                for await _ in AsyncStream.merging([posts, appBecameActiveTicks()]) {
                    reattachIfNeeded()
                }
            }
        }()
    #endif

    public static let liveValue: ExtensionIPCClient = {
        #if !os(macOS)
            // Once-guarded like any static: the initial attach inside it completes before any caller holds this
            // value, and concurrent first accesses wait rather than race it.
            _ = attachLifetime
        #endif
        return ExtensionIPCClient {
            region.store?.channels.connectionData.currentExtensionState()
                ?? .init(state: .disconnected(reason: .unset), requestId: nil)
        } currentStats: {
            region.store?.channels.localAgentStats.stats()
        } currentFeatures: {
            region.store?.channels.localAgentFeatures.agentFeatures()
        } currentExtensionError: {
            region.store?.channels.localAgentError.currentExtensionError()
        } currentPacketCapture: {
            region.store?.channels.packetCapture.packetCaptureReport() ?? .cleared
        } observeExtensionState: {
            region.stream(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.connectionData.readIfChanged(since: since)
            } transform: { payload in
                ExtensionStateSnapshot(
                    state: payload.extensionState,
                    requestId: payload.requestId
                )
            }
        } observeStats: {
            region.stream(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.localAgentStats.readIfChanged(since: since)
            } transform: { payload in
                payload.localAgentStats
            }
        } observeFeatures: {
            region.stream(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.localAgentFeatures.readIfChanged(since: since)
            } transform: { payload in
                payload.agentFeatures
            }
        } observeError: {
            region.stream(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.localAgentError.readIfChanged(since: since)
            } transform: { payload in
                payload.extensionError
            }
        } observePacketCapture: {
            region.stream(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.packetCapture.readIfChanged(since: since)
            } transform: { payload in
                payload.packetCaptureReport
            }
        } observeCommands: {
            IPCNotifications.streamRawState(.tunnelCmd)
                .map { Int($0) }
                .compactMap(TunnelCommand.init(rawValue:))
                .eraseToStream()
        } attachRegion: { surface in
            #if os(macOS)
                region.replace(when: { $0?.surfaceID != IOSurfaceGetID(surface) }) {
                    .attached(to: surface)
                }
            #else
                _ = surface
                assertionFailure("This should be used only on macOS")
            #endif
        } currentRegionID: {
            region.regionID
        }
    }()
}

#if DEBUG
    extension ExtensionIPCClient: TestDependencyKey {
        public static let testValue = ExtensionIPCClient(
            currentExtensionState: {
                @SharedReader(.mockExtensionState) var state
                return .init(state: state, requestId: nil)
            },
            currentStats: { nil },
            currentFeatures: { nil },
            currentExtensionError: { nil },
            currentPacketCapture: { .cleared },
            observeExtensionState: {
                // The reader is resolved per call so each test / `withDependencies` scope binds to its own value.
                @SharedReader(.mockExtensionState) var state
                let reader = $state
                return AsyncStream { continuation in
                    let task = Task {
                        // Drop the publisher's initial read so that the tests can define their own
                        for await value in reader.publisher.values.dropFirst() {
                            continuation.yield(.init(
                                state: value,
                                requestId: UUID()
                            ))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            observeStats: { .finished },
            observeFeatures: { .finished },
            observeError: { .finished },
            observePacketCapture: { .finished },
            observeCommands: { .finished },
            attachRegion: { _ in },
            currentRegionID: { nil }
        )
    }
#endif

#if DEBUG
    public extension SharedKey where Self == InMemoryKey<ExtensionState>.Default {
        // Used for publishing ExtensionState values in tests without going through the whole `RawChannel` machinery
        static var mockExtensionState: Self {
            Self[.inMemory("mockExtensionState"), default: .disconnected(reason: .unset)]
        }
    }
#endif

public extension DependencyValues {
    var extensionIPC: ExtensionIPCClient {
        get { self[ExtensionIPCClient.self] }
        set { self[ExtensionIPCClient.self] = newValue }
    }
}
