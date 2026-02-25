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
import Sharing

/// This defines what happens when you click on the expand button of the country row
/// We can show a list of cities and states with an option to navigate to list of servers
/// Or we can show servers directly for gateways and secure core servers.
public enum CityStateListType: Equatable {
    case cities([ServerGroupInfo])
    case states([ServerGroupInfo])
    case gateways([ServerInfo])
    case secureCores([ServerInfo])

    public init(groupInfo: ServerGroupInfo, search: String, secureCore: Bool = false) {
        @Dependency(\.serverRepository) var repository
        switch groupInfo.kind {
        case .city:
            self = .cities([groupInfo]) // never gets executed
        case .state:
            self = .states([groupInfo]) // never gets executed
        case let .country(code):
            if secureCore {
                let secureCores = repository
                    .getServers(filteredBy: [.kind(.country(code: code)), .features(.secureCore), .matches(search)], orderedBy: .nameAscending)
                self = .secureCores(secureCores)
            } else {
                self = .init(countryCode: code, search: search)
            }
        case let .gateway(name):
            let gateways = repository
                .getServers(filteredBy: [.kind(.gateway(name: name)), .matches(search)], orderedBy: .nameAscending)
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

public extension CityStateListType {
    var telemetryTrigger: UserInitiatedVPNChange.VPNTrigger {
        switch self {
        case .cities: .countriesCity
        case .states: .countriesState
        case .gateways: .gatewaysGateway
        case .secureCores: .countriesCountry
        }
    }
}
