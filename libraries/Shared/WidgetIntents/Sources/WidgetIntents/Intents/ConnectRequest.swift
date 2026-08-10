//
//  Created on 2026-08-10 by John Biggs.
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

import Connection
import ConnectionInventory
import Dependencies
import Domain
import Ergonomics
import Sharing
import VPNAppCore

/// Incoming connect request from an intent. Resolves the server (an explicit spec, recent entry, or the stored
/// default), checks tier rules, and sends the connect command. `send()` returns almost-immediately while
/// `sendAndAwaitOutcome()` waits until the tunnel settles and reports whether it connected.
struct ConnectRequest {
    let spec: ConnectionSpec?
    let recentIndex: Int?
    let skipReconnect: Bool

    private static let timeOut: Duration = .seconds(30)
    private static let transitionCheckInterval: Duration = .milliseconds(200)

    @SharedReader(.connectionState) private var connectionState
    @SharedReader(.recentConnections) private var recentConnections
    @SharedReader(.storedDefaultConnectionPreference) private var storedDefaultConnectionPreference

    struct IntentConnectionError: Error {}

    init(spec: ConnectionSpec? = nil, recentIndex: Int? = nil, skipReconnect: Bool = true) {
        self.spec = spec
        self.recentIndex = recentIndex
        self.skipReconnect = skipReconnect
    }

    func send() async throws {
        guard let resolvedSpec, isAllowed(resolvedSpec) else { return }
        if skipReconnect, try await isAlreadyConnected(to: resolvedSpec) { return }
        do {
            try sendConnectCommand(for: resolvedSpec)
        } catch {
            log.error("Failed to connect to VPN from widget with error: \(error)")
        }
    }

    func sendAndAwaitOutcome() async throws -> Bool {
        guard let resolvedSpec, isAllowed(resolvedSpec) else { return false }
        do {
            try await finishResolving()
        } catch {
            log.error("The connectionState hasn’t been changed from `resolving` in \(Self.timeOut) seconds. Skipping the widget connection intent.")
            return false
        }
        if skipReconnect, try await isAlreadyConnected(to: resolvedSpec) { return true }
        do {
            try sendConnectCommand(for: resolvedSpec)
            try await finishConnecting()
        } catch {
            log.error("Failed to connect to VPN from widget with error: \(error)")
            return false
        }
        try await $connectionState.load()
        return connectionState.is(\.connected)
    }

    // MARK: - Private helpers:

    private var resolvedSpec: ConnectionSpec? {
        spec ?? recentIndex.flatMap { recentConnection(at: $0) } ?? defaultConnection()
    }

    private func isAllowed(_ spec: ConnectionSpec) -> Bool {
        @SharedReader(.userTier) var userTier
        return userTier.isPaid || spec.location == .any(.fastest)
    }

    // Compares exact specs, so repeating a request while connected to its target does not reconnect.
    private func isAlreadyConnected(to spec: ConnectionSpec) async throws -> Bool {
        try await $connectionState.load()
        if case let .connected(tunnelConfig, _) = connectionState {
            return tunnelConfig.connectionSpec == spec
        }
        return false
    }

    private func sendConnectCommand(for spec: ConnectionSpec) throws {
        @Dependency(\.connectionCommandClient) var connectionCommandClient
        @SharedReader(.connectionProtocol) var connectionProtocol
        try connectionCommandClient.send(.connect(spec, connectionProtocol, .widget))
    }

    // Wait until the connection state is no longer .resolving.
    private func finishResolving() async throws {
        try await $connectionState.when(
            willMatch: { !$0.is(\.resolving) },
            every: Self.transitionCheckInterval,
            deadline: Self.timeOut,
            operation: { _ in }
        )
    }

    // Wait until the connection state reaches .connected or .disconnecting with the given spec, and then require a
    // transition to .connected.
    private func finishConnecting() async throws {
        try await $connectionState.when(willMatch: { state in
            switch state {
            case let .connected(tunnelConfig, _):
                tunnelConfig.connectionSpec == resolvedSpec

            case let .disconnecting(_, disconnectingSpec):
                disconnectingSpec == spec

            default:
                false
            }
        }, every: Self.transitionCheckInterval, deadline: Self.timeOut, operation: { state in
            guard case .connected = state else {
                throw IntentConnectionError()
            }
        })
    }

    private func recentConnection(at index: Int) -> ConnectionSpec? {
        @Dependency(\.connectionInventory) var connectionInventory
        return connectionInventory.recentConnectionList(
            storedDefaultConnectionPreference ?? .fastest,
            recentConnections ?? [],
            connectionState.resolvedSpec
        ).elements[safe: index]?.connection
    }

    private func defaultConnection() -> ConnectionSpec? {
        switch storedDefaultConnectionPreference ?? .fastest {
        case .fastest:
            return .defaultFastest
        case .mostRecent:
            let recents = recentConnections ?? []
            return recents.elements.first?.connection ?? .defaultFastest
        case let .recent(spec):
            return spec
        }
    }
}
