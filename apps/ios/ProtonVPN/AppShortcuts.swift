//
//  Created on 2026-02-09 by Pawel Jurczyk.
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
import WidgetIntents

enum AppShortcuts: AppShortcutsProvider { // these are visible as standalone shortcuts
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowConnectionStatus(),
            phrases: [
                "Am I protected by \(.applicationName)",
                "Is \(.applicationName) connected",
                "\(.applicationName) status",
                "Show \(.applicationName) status",
            ],
            shortTitle: "VPN status",
            systemImageName: "info.circle"
        )
        AppShortcut(
            intent: DisconnectVPNIntent(),
            phrases: [
                "Disconnect \(.applicationName)",
                "Disconnect from \(.applicationName)",
                "Don't protect me \(.applicationName)",
                "\(.applicationName) disconnect",
                "Turn off \(.applicationName)",
            ],
            shortTitle: "Disconnect VPN",
            systemImageName: "lock.open"
        )
        AppShortcut(
            intent: ConnectToVPNIntent(),
            phrases: [
                "Connect \(.applicationName)",
                "Connect with \(.applicationName)",
                "Protect me \(.applicationName)",
                "Connect to \(.applicationName)",
                "Start \(.applicationName)",
                "\(.applicationName) connect",
            ],
            shortTitle: "Connect VPN",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: ConnectToRegionIntent(),
            phrases: [
                "Connect to \(\.$country) with \(.applicationName)",
                "Connect to \(\.$city) with \(.applicationName)",
                "Connect to \(\.$state) with \(.applicationName)",
                "Connect \(.applicationName) to \(\.$country)",
                "Connect \(.applicationName) to \(\.$city)",
                "Connect \(.applicationName) to \(\.$state)",
                "Protect me \(.applicationName)",
                "Connect to \(.applicationName)",
                "\(.applicationName) connect",
            ],
            shortTitle: "Connect to region",
            systemImageName: "lock.fill"
        )
    }
}
