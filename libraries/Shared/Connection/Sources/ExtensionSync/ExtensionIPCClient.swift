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
import os
import Sharing

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

    /// The live connection state according to ProTUN in the network extension.
    public package(set) var observeExtensionState: @Sendable () -> AsyncStream<ExtensionStateSnapshot> = { .finished }
    /// The live NetShield / traffic stats.
    public package(set) var observeStats: @Sendable () -> AsyncStream<LocalAgent.Stats?> = { .finished }
    /// The server-applied Local Agent features.
    public package(set) var observeFeatures: @Sendable () -> AsyncStream<AgentTunnelFeatures?> = { .finished }
    /// The extension's most-recent reported error (`nil` when the slot is empty), decoded from the raw payload.
    public package(set) var observeError: @Sendable () -> AsyncStream<ExtensionError?> = { .finished }
    /// Commands the extension posts over the `.tunnelCmd` notification.
    public package(set) var observeCommands: @Sendable () -> AsyncStream<TunnelCommand> = { .finished }

    /// Attach the `IOSurface` received from the extension over XPC (macOS). Builds a fresh reader store; a reconnection
    /// re-attaches and observers re-subscribe (nothing observes while disconnected). No-op on iOS/tvOS, which use a
    /// fixed file mapping built up front.
    public var attachRegion: @Sendable (IOSurfaceRef) -> Void

    /// Identifies the tunnel-data region currently mapped, or `nil` when nothing is attached (macOS). Compared against
    /// the id the extension announces, to notice a mapping left behind by a process that no longer exists.
    public package(set) var currentRegionID: @Sendable () -> IOSurfaceID? = { nil }
}

#if os(macOS)
    extension ExtensionIPCClient: DependencyKey {
        private static let current = OSAllocatedUnfairLock<TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>?>(initialState: nil)

        // Per-observer read progress: resets whenever `current` points at a different store than last tick,
        // forcing an unconditional re-read (the attach tick itself is what triggers that reset in practice).
        private struct ReadState<T: Sendable>: Sendable {
            var surfaceID: ObjectIdentifier?
            var sequence = UInt64.max
            var value: T?
        }

        private typealias ReadHandler<Payload> = @Sendable (TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>, _ since: UInt64) -> (value: Payload?, sequence: UInt64)?

        // macOS has no IOSurface backing until the extension vends it on each (re)connection.
        // We want to merge multiple tick sources into one stream that lives for
        // the app's lifetime, and on every tick re-reads whatever `Self.current` points to right now.
        //
        // So we need a this specific observation helper. It explicitly avoids recent `swift-async-algorithm`
        // `flatMapLatest` because the way it is implemented isn't fitting the model we want here because of starvation issues
        // (inner vs outer tasks priorities)...
        // So we leverage `merge` here since it treats every source equally.
        private static func observe<Payload: BitwiseCopyable & Sendable, T: Sendable>(
            attachSource: StreamSource<TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>>,
            reconcileOn extraSignals: AsyncStream<Void>...,
            read: @escaping ReadHandler<Payload>,
            transform: @escaping @Sendable (Payload) -> T
        ) -> AsyncStream<T> {
            let attachTicks = attachSource.newStream.map { _ in () }.eraseToStream()
            let posts = IPCNotifications.streamRawState(.tunnelData).map { _ in () }.eraseToStream()
            let ticks: AsyncStream<Void> = ([posts] + extraSignals).reduce(attachTicks) {
                merge($0, $1).eraseToStream()
            }

            return UncheckedSendable(
                ticks
                    .reductions(into: ReadState<T>()) { acc, _ in
                        acc.value = nil
                        let store = current.withLock { $0 }
                        guard let store else { return }
                        let surfaceID = ObjectIdentifier(store.surface)
                        if acc.surfaceID != surfaceID {
                            acc.surfaceID = surfaceID
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
            let (attachStream, attachContinuation) = AsyncStream<TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>>.makeStream()
            let attachSource = StreamSource.source(for: attachStream)

            return ExtensionIPCClient {
                current.withLock { $0?.channels.connectionData.currentExtensionState() }
                    ?? .init(state: .disconnected(reason: .unset), requestId: nil)
            } currentStats: {
                current.withLock { $0?.channels.localAgentStats.stats() }
            } currentFeatures: {
                current.withLock { $0?.channels.localAgentFeatures.agentFeatures() }
            } currentExtensionError: {
                current.withLock { $0?.channels.localAgentError.currentExtensionError() }
            } observeExtensionState: {
                observe(attachSource: attachSource, reconcileOn: appBecameActiveTicks()) { store, since in
                    store.channels.connectionData.readIfChanged(since: since)
                } transform: { payload in
                    .init(
                        state: payload.extensionState,
                        requestId: payload.requestId
                    )
                }
            } observeStats: {
                observe(attachSource: attachSource, reconcileOn: appBecameActiveTicks()) { store, since in
                    store.channels.localAgentStats.readIfChanged(since: since)
                } transform: { payload in
                    payload.localAgentStats
                }
            } observeFeatures: {
                observe(attachSource: attachSource, reconcileOn: appBecameActiveTicks()) { store, since in
                    store.channels.localAgentFeatures.readIfChanged(since: since)
                } transform: { payload in
                    payload.agentFeatures
                }
            } observeError: {
                observe(attachSource: attachSource, reconcileOn: appBecameActiveTicks()) { store, since in
                    store.channels.localAgentError.readIfChanged(since: since)
                } transform: { payload in
                    payload.extensionError
                }
            } observeCommands: {
                IPCNotifications.streamRawState(.tunnelCmd)
                    .map { Int($0) }
                    .compactMap(TunnelCommand.init(rawValue:))
                    .eraseToStream()
            } attachRegion: { surface in
                // Each XPC fetch decodes a fresh IOSurface instance, so compare kernel surface ids rather than object
                // identity. Re-attaching the surface we already have must not reset observer read positions.
                let store = current.withLock { attached -> TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>? in
                    if let attached, attached.surfaceID == IOSurfaceGetID(surface) {
                        return nil
                    }
                    let store = TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>.attached(to: surface)
                    attached = store
                    return store
                }
                guard let store else { return }
                attachContinuation.yield(store)
            } currentRegionID: {
                current.withLock { $0?.surfaceID }
            }
        }()
    }
#else
    extension ExtensionIPCClient: DependencyKey {
        public static let liveValue: ExtensionIPCClient = {
            let store = TunnelDataStore<ReaderRole, FileBackedRegion>.live()
            return ExtensionIPCClient {
                store.channels.connectionData.currentExtensionState()
            } currentStats: {
                store.channels.localAgentStats.stats()
            } currentFeatures: {
                store.channels.localAgentFeatures.agentFeatures()
            } currentExtensionError: {
                store.channels.localAgentError.currentExtensionError()
            } observeExtensionState: {
                store.channels.connectionData.extensionStateStream(reconcileOn: appBecameActiveTicks())
            } observeStats: {
                store.channels.localAgentStats.statsStream(reconcileOn: appBecameActiveTicks())
            } observeFeatures: {
                store.channels.localAgentFeatures.agentFeaturesStream(reconcileOn: appBecameActiveTicks())
            } observeError: {
                store.channels.localAgentError.errorStream(reconcileOn: appBecameActiveTicks())
            } observeCommands: {
                IPCNotifications.streamRawState(.tunnelCmd)
                    .map { Int($0) }
                    .compactMap(TunnelCommand.init(rawValue:))
                    .eraseToStream()
            } attachRegion: { _ in
                assertionFailure("This should be used only on macOS")
            } currentRegionID: {
                // The mapping here is a file that lives as long as the app does, so there is no region identity to
                // compare and nothing that can go stale underneath us.
                nil
            }
        }()
    }
#endif

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
