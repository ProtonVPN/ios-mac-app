//
//  Created on 2026-02-10 by Pawel Jurczyk.
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

import AppIntents
import Connection
import ConnectionInventory
import Dependencies
import Domain
import Ergonomics
import Sharing
import UIKit
import VPNAppCore

public struct ConnectToVPNWithParametersIntent: AppIntent {
    public static let title: LocalizedStringResource = "Connect to VPN with parameters"
    public static let openAppWhenRun = true
    public static let isDiscoverable: Bool = false

    private static let timeOut: Duration = .seconds(20)

    public var skipReconnect: Bool = true
    var recentIndex: Int?
    var connectionSpec: ConnectionSpec?

    @SharedReader(.connectionState) var connectionState

    struct IntentConnectionError: Error {}

    public init() {}

    public init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    public init(connectionSpec: ConnectionSpec, skipReconnect: Bool) {
        self.connectionSpec = connectionSpec
        self.skipReconnect = skipReconnect
    }

    // This is the spec that will be used for the connection
    var spec: ConnectionSpec? {
        connectionSpec ?? recentIndex.flatMap(getRecentConnection) ?? getDefaultConnection()
    }

    func finishResolving() async throws {
        // Wait until the connection state is not .resolving
        try await $connectionState.when(
            willMatch: { !$0.is(\.resolving) },
            every: .milliseconds(20),
            deadline: Self.timeOut,
            operation: { _ in }
        )
    }

    func finishConnecting() async throws {
        // Wait until the connection state either goes into .connected or .disconnecting.
        try await $connectionState.when(willMatch: { state in
            switch state {
            case let .connected(intent, _, _, _), let .disconnecting(intent, _):
                intent.spec == spec
            default:
                false
            }
        }, every: .milliseconds(20), deadline: Self.timeOut, operation: { state in
            if case .connected = state {
                if connectionSpec == nil { // don't close the app when connecting with a spec
                    // VPN connection established, now suspending the app.
                    try? await Task.sleep(for: .seconds(1))
                    await MainActor.run {
                        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                    }
                }
            } else {
                throw IntentConnectionError()
            }
        })
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        guard let spec else {
            return .result(value: false)
        }
        @SharedReader(.userTier) var userTier
        guard userTier?.isFreeTier == false || spec.location == .any(.fastest) else {
            return .result(value: false)
        }
        do {
            try await finishResolving()
        } catch {
            log.error("The connectionState hasn’t been changed from `resolving` in \(Self.timeOut) seconds. Skipping the widget connection intent.")
            return .result(value: false)
        }

        if skipReconnect {
            /// We can check if the desired connection spec falls under the current spec.
            /// So if current spec is Sydney and user wants to connect to Australia, which is a different spec,
            /// but the current spec falls under it - we can skip the reconnect.
            /// For now just compare the exact specs, so the same shortcut launched multiple times will not re-trigger a connection
            if case let .connected(intent, _, _, _) = connectionState {
                if intent.spec == spec {
                    return .result(value: true)
                }
            }
        }

        @Dependencies.Dependency(\.connectToVPN) var connectToVPN

        do {
            // Trigger connection
            try await connectToVPN(spec, defaultConnectionStorage.getDefaultProtocol(), .widget)
            try await finishConnecting()
        } catch {
            log.error("Failed to connect to VPN from widget with error: \(error)")
            return .result(value: false)
        }

        if case .connected = connectionState {
            return .result(value: true)
        } else {
            return .result(value: false)
        }
    }

    // MARK: - Private helpers:

    @Dependencies.Dependency(\.recentsStorage) private var recentsStorage
    @Dependencies.Dependency(\.defaultConnectionStorage) private var defaultConnectionStorage

    private func getRecentConnection(_ index: Int) -> ConnectionSpec? {
        @Dependencies.Dependency(\.connectionInventory) var connectionInventory

        return connectionInventory.recentConnectionList(
            .fastest,
            recentsStorage.readFromStorage(),
            ConnectionSpec.defaultFastest
        ).elements[safe: index]?.connection
    }

    private func getDefaultConnection() -> ConnectionSpec? {
        let preference = try? defaultConnectionStorage.getPreference()
        switch preference ?? .fastest {
        case .fastest:
            return .defaultFastest
        case .mostRecent:
            let recents = recentsStorage.readFromStorage()
            return recents.elements.first?.connection ?? .defaultFastest
        case let .recent(spec):
            return spec
        }
    }
}
