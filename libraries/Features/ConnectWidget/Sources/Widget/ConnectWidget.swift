//
//  Created on 2025-01-09.
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

import Strings
import SwiftUI
import Theme
import WidgetKit

public struct ConnectWidget: Widget {
    static let kind: String = "ConnectWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: Provider()) { entry in
            ConnectWidgetView(entry: entry)
        }
        .configurationDisplayName("Proton VPN")
        .description(Localizable.widgetTrayDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    ConnectWidget()
} timeline: {
    ConnectWidgetEntry(
        date: .now,
        connectionSpec: .defaultFastest,
        currentServer: nil,
        protectionState: .protected,
        recentServers: []
    )
}
