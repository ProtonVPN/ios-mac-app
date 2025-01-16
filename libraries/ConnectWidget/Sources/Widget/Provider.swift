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

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ConnectWidgetEntry {
        .init(date: .now, signedIn: true, protectionState: .protected)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConnectWidgetEntry) -> ()) {
        completion(ConnectWidgetEntry(date: .now, signedIn: true, protectionState: .protected))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [ // Temporary entries.
            ConnectWidgetEntry(date: .now, signedIn: false, protectionState: .unprotected),
            ConnectWidgetEntry(date: .now.addingTimeInterval(4), signedIn: true, protectionState: .unprotected),
            ConnectWidgetEntry(date: .now.addingTimeInterval(6), signedIn: true, protectionState: .protecting),
            ConnectWidgetEntry(date: .now.addingTimeInterval(8), signedIn: true, protectionState: .protected)
        ], policy: .never)) // at least one entry here is needed, otherwise the widget fails to update for a new connection status
    }
}

public enum ProtectionState: Equatable {
    case protected
    case unprotected
    case protecting
}

// Still WIP
public struct ConnectWidgetEntry: TimelineEntry {
    public let date: Date
    let signedIn: Bool
    let protectionState: ProtectionState
}
