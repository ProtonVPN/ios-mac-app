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
import Domain
import UIKit

public enum ShortcutItem {
    case connect
    case connectToFirstPinnedRecent(RecentConnection)
    case disconnect

    public var type: String {
        switch self {
        case .connect:
            "ConnectType"
        case .connectToFirstPinnedRecent:
            "ConnectPinnedRecentType"
        case .disconnect:
            "DisconnectType"
        }
    }
}

public extension ShortcutItem {
    var shortcutItem: UIApplicationShortcutItem {
        switch self {
        case .connect:
            UIApplicationShortcutItem(
                type: type,
                localizedTitle: "Connect",
                localizedSubtitle: "Connect to VPN",
                icon: UIApplicationShortcutIcon(systemImageName: "lock.fill")
            )
        case let .connectToFirstPinnedRecent(recent):
            UIApplicationShortcutItem(
                type: type,
                localizedTitle: "Connect to \(recent.connection.location.text(locale: .current))",
                localizedSubtitle: recent.connection.location.subtext(locale: .current),
                icon: UIApplicationShortcutIcon(systemImageName: "pin.fill")
            )
        case .disconnect:
            UIApplicationShortcutItem(
                type: type,
                localizedTitle: "Disconnect",
                localizedSubtitle: "Disconnect from VPN",
                icon: UIApplicationShortcutIcon(systemImageName: "lock.open")
            )
        }
    }
}
