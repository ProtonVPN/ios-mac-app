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
import ConnectionPresenter
import OrderedCollections
import AppIntents
import ComposableArchitecture

struct Provider: TimelineProvider {

    @Dependency(\.authKeychain) var authKeychain
    @Dependency(\.recentsStorage) var recentsStorage
    @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage
    @Dependency(\.connectionPresenter) var connectionPresenter
    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

    func recentConnectionList() -> [RecentConnection] {

        let preference = try? defaultConnectionStorage.getPreference()

        return connectionPresenter.recentConnectionList(
            defaultConnectionPreference: preference ?? .fastest,
            recents: recentsStorage.readFromStorage(),
            currentConnection: ConnectionSpec.defaultFastest
        ).elements
    }

    func placeholder(in context: Context) -> ConnectWidgetEntry {
        .init(date: .now,
              connectionSpec: .defaultFastest,
              protectionState: .protected,
              recentServers: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ConnectWidgetEntry) -> ()) {
        completion(ConnectWidgetEntry(date: .now,
                                      connectionSpec: .defaultFastest,
                                      protectionState: .protected,
                                      recentServers: []))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry: ConnectWidgetEntry

        let credentials: AuthCredentials? = authKeychain.fetch(forContext: nil)
        guard credentials?.userId != nil else {
            entry = ConnectWidgetEntry(date: .now,
                                       connectionSpec: nil,
                                       protectionState: .signedOut,
                                       recentServers: [])
            completion(Timeline(entries: [entry], policy: .never))
            return
        }

        let recents = recentConnectionList()

        entry = ConnectWidgetEntry(date: .now,
                                   connectionSpec: vpnConnectionStatus.spec ?? connectionSpec(),
                                   protectionState: vpnConnectionStatus.protectionState,
                                   recentServers: recents)
        completion(Timeline(entries: [entry], policy: .never))
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
}

struct ConnectShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ConnectToVPNIntent(),
                    phrases: ["Connect to VPN"],
                    shortTitle: "Connect to VPN",
                    systemImageName: "square")
    }
}


extension VPNConnectionStatus {
    var protectionState: ConnectWidgetEntry.ProtectionState {
        switch self {
        case .resolving:
            return .unprotected // Do we need another state for this?
        case .disconnected:
            return .unprotected
        case .connecting:
            return .protecting
        case .connected:
            return .protected
        case .disconnecting:
            return .unprotected
        }
    }
}
