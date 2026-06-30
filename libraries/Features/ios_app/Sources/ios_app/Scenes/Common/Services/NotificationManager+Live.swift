//
//  Created on 26/06/2026 by Max Kupetskyi.
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

import Dependencies
import Ergonomics
import Strings
import VPNAppCore

extension NotificationManager: @retroactive DependencyKey {
    public static let liveValue = NotificationManager(
        displayServerGoingOnMaintenance: {
            executeOnUIThread {
                @Dependency(\.windowService) var windowService
                windowService.presentMessage(Localizable.maintenanceOnServerDetectedTitle, .success, nil)
            }
        },
        // Port forwarding is macOS-only; these are intentionally no-ops on iOS.
        displayPFChange: { _ in },
        displayPFError: {}
    )
}
