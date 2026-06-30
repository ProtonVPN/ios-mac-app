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
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import IPCErgonomics
import LocalAgentIPC
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
    public package(set) var currentExtensionState: @Sendable () -> (ExtensionState, UUID?) = {
        (.disconnected(reason: .unset), nil)
    }

    /// The current NetShield / traffic stats, or `nil` before the extension has published any.
    public package(set) var currentStats: @Sendable () -> LocalAgent.Stats?
    /// The current server-applied Local Agent features, or `nil` before the extension has published any.
    public package(set) var currentFeatures: @Sendable () -> AgentTunnelFeatures?
    /// The extension's most-recent reported error, or `nil` if it's empty.
    public package(set) var currentExtensionError: @Sendable () -> ExtensionError? = { nil }

    /// The live connection state according to ProTUN in the network extension.
    public package(set) var observeExtensionState: @Sendable () -> AsyncStream<(state: ExtensionState, requestId: UUID?)> = { .finished }
    /// The live NetShield / traffic stats.
    public package(set) var observeStats: @Sendable () -> AsyncStream<LocalAgent.Stats?> = { .finished }
    /// The server-applied Local Agent features.
    public package(set) var observeFeatures: @Sendable () -> AsyncStream<AgentTunnelFeatures?> = { .finished }
    /// The extension's most-recent reported error (`nil` when the slot is empty), decoded from the raw payload.
    public package(set) var observeError: @Sendable () -> AsyncStream<ExtensionError?> = { .finished }
    /// Commands the extension posts over the `.tunnelCmd` notification.
    public package(set) var observeCommands: @Sendable () -> AsyncStream<TunnelCommand> = { .finished }

    /// macOS: attach the `IOSurface` region received from the extension over XPC so reads/streams resolve against it.
    public package(set) var attachRegion: @Sendable (IPCNotifications.SharedRegion) -> Void
}

extension ExtensionIPCClient: DependencyKey {
    public static let liveValue: ExtensionIPCClient = {
        #if DEBUG && targetEnvironment(simulator)
            // No network extension runs in the simulator, so reuse the in-memory `testValue` to fake a connection
            return .testValue
        #else
            let store = TunnelDataStore<IPCNotifications.Reader>.live()
            return ExtensionIPCClient(
                currentExtensionState: { store.channels.connectionData.currentExtensionState() },
                currentStats: { store.channels.localAgentStats.stats() },
                currentFeatures: { store.channels.localAgentFeatures.agentFeatures() },
                currentExtensionError: { store.channels.localAgentError.currentExtensionError() },
                observeExtensionState: { store.channels.connectionData.extensionStateStream(reconcileOn: appBecameActiveTicks()) },
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
        #endif
    }()

    #if DEBUG
        public static let testValue = ExtensionIPCClient(
            currentExtensionState: {
                @SharedReader(.mockExtensionState) var state
                return (state, nil)
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
                            continuation.yield((value, UUID()))
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
            attachRegion: { _ in }
        )
    #endif
}

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
