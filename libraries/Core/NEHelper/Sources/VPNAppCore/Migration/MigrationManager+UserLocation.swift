//
//  Created on 05/08/2026 by Max Kupetskyi.
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
    /// Folds the separate `userIP` / `userCountry` / `userISP` / `lastLocationRetrieval` defaults into
    /// the single ``StoredUserLocation`` under `UserLocation`.
    func checkingUserLocation() -> Self {
        checking(.platform(iOS: "7.5.3", macOS: "6.5.2", tvOS: "1.6.0")) { _ in
            @Dependency(\.defaultAppStorage) var defaults

            defer {
                for key in legacyUserLocationKeys {
                    defaults.removeObject(forKey: key)
                }
            }

            guard let ip = defaults.string(forKey: "userIP") else { return }
            let location = UserLocation(
                ip: ip,
                // Stored lowercased by the home screen; the endpoint reports it uppercased, which is
                // what every reader of the unified value now sees.
                country: defaults.string(forKey: "userCountry")?.uppercased() ?? "",
                isp: defaults.string(forKey: "userISP") ?? ""
            )
            let measuredAt = defaults.object(forKey: "lastLocationRetrieval") as? Date

            @Shared(.userLocation) var userLocation
            $userLocation.adoptLegacy(location, measuredAt: measuredAt)
            log.info(
                "Migrated user location defaults into a single value",
                category: .persistence,
                metadata: ["hasRetrievalDate": "\(measuredAt != nil)"]
            )
        }
    }
}

/// The defaults the location used to be spread across.
private let legacyUserLocationKeys = ["userIP", "userCountry", "userISP", "lastLocationRetrieval"]
