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

import AsyncAlgorithms
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
    #if os(macOS)
        private typealias ReaderStore = TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>
    #else
        private typealias ReaderStore = TunnelDataStore<ReaderRole, ReadOnlyFileBackedRegion>
    #endif

    private static let current = OSAllocatedUnfairLock<ReaderStore?>(initialState: nil)

    /// The store for the region the writer last announced, or `nil` if none has been observed.
    private static var attachedStore: ReaderStore? {
        current.withLock { $0 }
    }

    /// Ticks the observe streams when a fresh region attaches, so they read it without waiting for a post.
    private static let attachTicks: (source: StreamSource<Void>, continuation: AsyncStream<Void>.Continuation) = {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        return (StreamSource.source(for: stream), continuation)
    }()

    #if !os(macOS)
        private static let attachQueue = DispatchQueue(label: "ProtonVPN.ExtensionIPCClient.attach")

        /// Remaps `current` when the announcement names a different region. Serialized on `attachQueue`.
        private static func reattachIfNeeded() {
            let announced = IPCNotifications.getRawState(.tunnelData)
            guard announced != 0, current.withLock({ $0?.regionID }) != announced else { return }

            let fresh: ReaderStore
            do {
                fresh = try ReaderStore.openedForReading()
            } catch {
                // A locked device seals the file. Keep what is mapped and retry on the next attach event.
                log.error("Could not map announced tunnel-data region \(announced): \(error)")
                return
            }

            current.withLock { $0 = fresh }
            attachTicks.continuation.yield(())
        }

        /// App-lifetime attach machinery: an initial attach, a reattach on every `.tunnelData` post, and checking when
        /// we come back to foreground to see if anything was posted while we were suspended.
        private static let attachLifetime: (posts: IPCNotifications.Observation, appActive: Task<Void, Never>) = {
            // Reattach before the observer so a pre-existing tunnel gets mapped before the first state read
            reattachIfNeeded()
            let posts = IPCNotifications.observeRawState(.tunnelData, queue: attachQueue) { _ in
                reattachIfNeeded()
            }.observation()
            let appActive = Task {
                for await _ in appBecameActiveTicks() {
                    attachQueue.async { reattachIfNeeded() }
                }
            }
            return (posts, appActive)
        }()
    #endif

    // Future: The region id stands in for object identity because casting a class with noncopyable generic parameters
    // to AnyObject needs the iOS 18 runtime.
    private struct ReadState<T: Sendable>: Sendable {
        var regionID: UInt64?
        var sequence = UInt64.max
        var value: T?
    }

    private typealias ReadHandler<Payload> = @Sendable (ReaderStore, _ since: UInt64) -> (value: Payload?, sequence: UInt64)?

    /// One stream over one channel that survives the region being replaced underneath it. Each tick re-resolves the
    /// store and emits when the channel's sequence moved.
    private static func observe<Payload: BitwiseCopyable & Sendable, T: Sendable>(
        reconcileOn extraSignals: AsyncStream<Void>...,
        read: @escaping ReadHandler<Payload>,
        transform: @escaping @Sendable (Payload) -> T
    ) -> AsyncStream<T> {
        let attach = attachTicks.source.newStream
        let posts = IPCNotifications.streamRawState(.tunnelData).map { _ in () }.eraseToStream()
        let ticks: AsyncStream<Void> = ([posts] + extraSignals).reduce(attach) {
            merge($0, $1).eraseToStream()
        }

        return UncheckedSendable(
            ticks
                .reductions(into: ReadState<T>()) { acc, _ in
                    acc.value = nil
                    guard let store = attachedStore else { return }
                    let regionID = store.regionID
                    if acc.regionID != regionID {
                        acc.regionID = regionID
                        acc.sequence = .max
                    }
                    guard let (payload, sequence) = read(store, acc.sequence) else { return }
                    acc.sequence = sequence
                    guard let payload else { return }
                    acc.value = transform(payload)
                }
                .compactMap(\.value)
        ).eraseToStream()
    }

    public static let liveValue: ExtensionIPCClient = {
        #if !os(macOS)
            _ = attachLifetime
        #endif
        return ExtensionIPCClient {
            attachedStore?.channels.connectionData.currentExtensionState()
                ?? .init(state: .disconnected(reason: .unset), requestId: nil)
        } currentStats: {
            attachedStore?.channels.localAgentStats.stats()
        } currentFeatures: {
            attachedStore?.channels.localAgentFeatures.agentFeatures()
        } currentExtensionError: {
            attachedStore?.channels.localAgentError.currentExtensionError()
        } currentPacketCapture: {
            attachedStore?.channels.packetCapture.packetCaptureReport() ?? .cleared
        } observeExtensionState: {
            observe(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.connectionData.readIfChanged(since: since)
            } transform: { payload in
                ExtensionStateSnapshot(
                    state: payload.extensionState,
                    requestId: payload.requestId
                )
            }
        } observeStats: {
            observe(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.localAgentStats.readIfChanged(since: since)
            } transform: { payload in
                payload.localAgentStats
            }
        } observeFeatures: {
            observe(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.localAgentFeatures.readIfChanged(since: since)
            } transform: { payload in
                payload.agentFeatures
            }
        } observeError: {
            observe(reconcileOn: appBecameActiveTicks()) { store, since in
                store.channels.localAgentError.readIfChanged(since: since)
            } transform: { payload in
                payload.extensionError
            }
        } observePacketCapture: {
            observe(reconcileOn: appBecameActiveTicks()) { store, since in
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
                let attached = current.withLock { store -> Bool in
                    if let mapped = store, mapped.surfaceID == IOSurfaceGetID(surface) { return false }
                    store = ReaderStore.attached(to: surface)
                    return true
                }
                if attached {
                    attachTicks.continuation.yield(())
                }
            #else
                _ = surface
                assertionFailure("This should be used only on macOS")
            #endif
        } currentRegionID: {
            current.withLock { $0?.regionID }
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
