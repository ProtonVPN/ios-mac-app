//
//  Created on 2025-01-15.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import AppIntents
import ComposableArchitecture
import ConnectionInventory
import Dependencies
import Domain
import OrderedCollections
import VPNAppCore
import VPNShared
import WidgetKit

struct Provider: TimelineProvider {
    @Dependency(\.authKeychain) var authKeychain
    @SharedReader(.recentConnections) var recentConnections
    @SharedReader(.storedDefaultConnectionPreference) var storedDefaultConnectionPreference
    @Dependency(\.connectionInventory) var connectionInventory
    @SharedReader(.vpnConnectionStatusDoNotUse) var vpnConnectionStatusDoNotUse: VPNConnectionStatusDoNotUse

    func recentConnectionList() -> [RecentConnection] {
        let preference = storedDefaultConnectionPreference

        return connectionInventory.recentConnectionList(
            preference ?? .fastest,
            recentConnections ?? [],
            ConnectionSpec.defaultFastest
        ).elements
    }

    func placeholder(in _: Context) -> ConnectWidgetEntry {
        .init(
            date: .now,
            connectionSpec: .defaultFastest,
            currentServer: nil,
            protectionState: .protected,
            recentServers: []
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (ConnectWidgetEntry) -> Void) {
        completion(createTimelineEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [createTimelineEntry()], policy: .never))
    }

    private func connectionSpec() -> ConnectionSpec {
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

    private func createTimelineEntry() -> ConnectWidgetEntry {
        let credentials: AuthCredentials? = authKeychain.fetch()

        guard credentials?.userId != nil else {
            return ConnectWidgetEntry(
                date: .now,
                connectionSpec: nil,
                currentServer: nil,
                protectionState: .signedOut,
                recentServers: []
            )
        }

        let recents = recentConnectionList()

        return ConnectWidgetEntry(
            date: .now,
            connectionSpec: vpnConnectionStatusDoNotUse.connectionSpec ?? connectionSpec(),
            currentServer: vpnConnectionStatusDoNotUse.server,
            protectionState: vpnConnectionStatusDoNotUse.protectionState,
            recentServers: recents
        )
    }
}

private extension VPNConnectionStatusDoNotUse {
    var protectionState: ConnectWidgetEntry.ProtectionState {
        switch self {
        case .resolving, .disconnected, .disconnecting:
            .unprotected
        case .connecting:
            .protecting
        case .connected:
            .protected
        }
    }

    var connectionSpec: ConnectionSpec? {
        switch self {
        case .resolving, .disconnected, .disconnecting:
            nil
        case .connecting, .connected:
            spec
        }
    }
}
