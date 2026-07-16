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

public struct ConnectVPNWithParametersAndReturnIntent: AppIntent {
    public static let title: LocalizedStringResource = "Connect to VPN with parameters"
    public static let openAppWhenRun = true
    public static let isDiscoverable: Bool = false

    public var skipReconnect: Bool = true
    /// We need this property to be marked as @Parameter, even though it's not visible to the user
    /// Otherwise the widget `forgets` about this and uses the default connection instead of the recent one
    @Parameter(title: "Recent Index")
    var recentIndex: Int?
    var connectionSpec: ConnectionSpec?

    @SharedReader(.connectionState) var connectionState

    struct IntentConnectionError: Error {}

    public init() {}

    public init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    public init(connectionSpec: ConnectionSpec, skipReconnect: Bool = true) {
        self.connectionSpec = connectionSpec
        self.skipReconnect = skipReconnect
    }

    // This is the spec that will be used for the connection
    var spec: ConnectionSpec? {
        connectionSpec ?? recentIndex.flatMap(getRecentConnection) ?? getDefaultConnection()
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        guard let spec else {
            return .result(value: false)
        }
        @SharedReader(.userTier) var userTier
        guard userTier?.isFreeTier == false || spec.location == .any(.fastest) else {
            return .result(value: false)
        }


        if skipReconnect {
            /// We can check if the desired connection spec falls under the current spec.
            /// So if current spec is Sydney and user wants to connect to Australia, which is a different spec,
            /// but the current spec falls under it - we can skip the reconnect.
            /// For now just compare the exact specs, so the same shortcut launched multiple times will not re-trigger a connection
            try await $connectionState.load()
            if case let .connected(tunnelConfig, _) = connectionState {
                if tunnelConfig.connectionSpec == spec {
                    return .result(value: true)
                }
            }
        }

        do {
            @Dependencies.Dependency(\.connectionCommandClient) var connectionCommandClient
            @SharedReader(.connectionProtocol) var connectionProtocol
            try connectionCommandClient.send(.connect(spec, connectionProtocol, .widget))
        } catch {
            log.error("Failed to connect to VPN from widget with error: \(error)")
            return .result(value: false)
        }
        return .result(value: true)
    }

    // MARK: - Private helpers:

    @SharedReader(.recentConnections) private var recentConnections
    @SharedReader(.storedDefaultConnectionPreference) private var storedDefaultConnectionPreference

    private func getRecentConnection(_ index: Int) -> ConnectionSpec? {
        @Dependencies.Dependency(\.connectionInventory) var connectionInventory
        @SharedReader(.recentConnections) var recentConnections
        @SharedReader(.storedDefaultConnectionPreference) var storedDefaultConnectionPreference
        return connectionInventory.recentConnectionList(
            storedDefaultConnectionPreference ?? .fastest,
            recentConnections ?? [],
            connectionState.resolvedSpec).elements[safe: index]?.connection
    }

    private func getDefaultConnection() -> ConnectionSpec? {
        let preference = storedDefaultConnectionPreference
        switch preference ?? .fastest {
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
