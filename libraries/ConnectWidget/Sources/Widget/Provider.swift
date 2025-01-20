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

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ConnectWidgetEntry {
        .init(date: .now, connectionSpec: .defaultFastest, protectionState: .protected, recentServers: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ConnectWidgetEntry) -> ()) {
        completion(ConnectWidgetEntry(date: .now, connectionSpec: .defaultFastest, protectionState: .protected, recentServers: []))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [ // Temporary entries.
            ConnectWidgetEntry(date: .now, connectionSpec: nil, protectionState: .signedOut, recentServers: []),
            ConnectWidgetEntry(date: .now.addingTimeInterval(4), connectionSpec: .defaultFastest, protectionState: .unprotected, recentServers: [.defaultFastest]),
            ConnectWidgetEntry(date: .now.addingTimeInterval(6), connectionSpec: .init(location: .region(code: "US"), features: []), protectionState: .protecting, recentServers: [.defaultFastest]),
            ConnectWidgetEntry(date: .now.addingTimeInterval(8), connectionSpec: .init(location: .region(code: "CH"), features: []), protectionState: .protected, recentServers: [.defaultFastest]),
            ConnectWidgetEntry(date: .now.addingTimeInterval(10), connectionSpec: .init(location: .exact(.paid, number: 123, subregion: "LA", regionCode: "US"), features: []), protectionState: .protected, recentServers: [
                .defaultFastest,
                .init(pinnedDate: nil, underMaintenance: false, connectionDate: Date(), connection: .init(location: .exact(.paid, number: 332, subregion: "ZU", regionCode: "CH"), features: [])),
                .init(pinnedDate: nil, underMaintenance: true, connectionDate: Date(), connection: .init(location: .exact(.paid, number: 332, subregion: "MI", regionCode: "IT"), features: []))
            ])
        ], policy: .never)) // at least one entry here is needed, otherwise the widget fails to update for a new connection status
    }
}
