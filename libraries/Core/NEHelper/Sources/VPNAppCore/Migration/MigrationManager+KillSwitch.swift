//
//  Created on 22/06/2026 by Max Kupetskyi.
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
import Domain
import Ergonomics
import Foundation
import Sharing

extension MigrationManager {
    /// Migrates the legacy binary kill switch (`Firewall` boolean) to the three-state ``KillSwitchMode``.
    ///
    /// Users who had the kill switch **on** migrate to **Standard**.
    /// Users with it off (and new users) default to Off.
    func checkingKillSwitchMode() -> Self {
        checking(.platform(iOS: "7.5.2", macOS: nil, tvOS: nil)) { _ in
            @Dependency(\.defaultAppStorage) var defaults

            // Don't overwrite a mode the user may already have chosen via the new picker.
            guard defaults.object(forKey: KillSwitchMode.storageKey) == nil else { return }

            let wasEnabled = defaults.bool(forKey: "Firewall")
            let mode: KillSwitchMode = wasEnabled ? .standard : .off
            defaults.set(mode.rawValue, forKey: KillSwitchMode.storageKey)
            log.info(
                "Migrated kill switch to 3-state mode",
                category: .persistence,
                metadata: ["wasEnabled": "\(wasEnabled)", "mode": "\(mode)"]
            )
        }
    }
}
