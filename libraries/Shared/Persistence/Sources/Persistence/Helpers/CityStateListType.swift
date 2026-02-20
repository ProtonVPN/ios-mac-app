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

public enum CityStateListType: Equatable {
    case cities([ServerGroupInfo])
    case states([ServerGroupInfo])
    case gateways([ServerGroupInfo])

    public init(groupInfo: ServerGroupInfo, search: String) {
        switch groupInfo.kind {
        case .city:
            self = .cities([groupInfo])
        case .state:
            self = .states([groupInfo])
        case let .country(code):
            self = .init(countryCode: code, search: search)
        case let .gateway(name):
            @Dependency(\.serverRepository) var repository
            let gateways = repository
                .getGroups(
                    filteredBy: [.isNotUnderMaintenance, .kind(.gateway(name: name)), .matches(search)],
                    groupedBy: .serverType
                )
            self = .gateways(gateways)
        }
    }

    public init(countryCode: String, search: String) {
        @Dependency(\.serverRepository) var repository

        let states = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode)), .matches(search)],
                groupedBy: .stateName
            ).filter { element in
                guard case .state = element.kind else { return false }
                return true
            }

        guard states.isEmpty else {
            self = .states(states)
            return
        }

        let cities = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode)), .matches(search)],
                groupedBy: .cityName
            ).filter { element in
                guard case .city = element.kind else { return false }
                return true
            }

        self = .cities(cities)
    }
}
