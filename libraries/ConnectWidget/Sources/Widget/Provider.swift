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

import WidgetKit
import Domain
import Dependencies
import VPNShared
import VPNAppCore
import ConnectionInventory
import OrderedCollections
import AppIntents
import ComposableArchitecture

struct Provider: TimelineProvider {

    @Dependency(\.authKeychain) var authKeychain
    @Dependency(\.recentsStorage) var recentsStorage
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage
    @Dependency(\.connectionInventory) var connectionInventory
    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

    func recentConnectionList() -> [RecentConnection] {

        let preference = try? defaultConnectionStorage.getPreference()

        return connectionInventory.recentConnectionList(
            preference ?? .fastest,
            recentsStorage.readFromStorage(),
            ConnectionSpec.defaultFastest
        ).elements
    }

    func placeholder(in context: Context) -> ConnectWidgetEntry {
        .init(date: .now,
              connectionSpec: .defaultFastest,
              protectionState: .protected,
              recentServers: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ConnectWidgetEntry) -> ()) {
        completion(createTimelineEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [createTimelineEntry()], policy: .never))
    }

    private func connectionSpec() -> ConnectionSpec {
        let preference = try? defaultConnectionStorage.getPreference()
        switch preference ?? .fastest {
        case .fastest:
            return .defaultFastest
        case .mostRecent:
            let recents = recentsStorage.readFromStorage()
            return recents.elements.first?.connection ?? .defaultFastest
        case .recent(let spec):
            return spec
        }
    }

    private func createTimelineEntry() -> ConnectWidgetEntry {
        let credentials: AuthCredentials? = authKeychain.fetch()

        guard credentials?.userId != nil else {
            return ConnectWidgetEntry(date: .now,
                                       connectionSpec: nil,
                                       protectionState: .signedOut,
                                       recentServers: [])
        }

        let recents = recentConnectionList()

        return ConnectWidgetEntry(date: .now,
                                   connectionSpec: vpnConnectionStatus.spec ?? connectionSpec(),
                                   protectionState: vpnConnectionStatus.protectionState,
                                   recentServers: recents
        )
    }
}

private extension VPNConnectionStatus {
    var protectionState: ConnectWidgetEntry.ProtectionState {
        switch self {
        case .resolving, .disconnected, .disconnecting:
            return .unprotected
        case .connecting:
            return .protecting
        case .connected:
            return .protected
        }
    }
}
