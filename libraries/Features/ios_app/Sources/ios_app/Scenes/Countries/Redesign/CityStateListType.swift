//
//  Created on 2026-01-13 by Pawel Jurczyk.
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
import Persistence

enum CityStateListType: Equatable {
    case cities([String])
    case states([String])

    init(countryCode: String) {
        @Dependency(\.serverRepository) var repository

        let stateNames = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode))],
                groupedBy: .stateName
            )
            .compactMap(\.stateName)

        guard stateNames.isEmpty else {
            self = .states(stateNames)
            return
        }

        let cityNames = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode))],
                groupedBy: .cityName
            )
            .compactMap(\.cityName)

        self = .cities(cityNames)
    }
}

private extension ServerGroupInfo {
    var cityName: String? {
        guard case let .city(name, _) = kind else { return nil }
        return name
    }

    var stateName: String? {
        guard case let .state(name, _) = kind else { return nil }
        return name
    }
}
