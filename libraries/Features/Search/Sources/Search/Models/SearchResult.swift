//
//  Created on 03.03.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import Strings

enum SearchResult {
    case upsell
    case countries(countries: [CountryViewModel])
    case cities(cities: [CityViewModel])
    case states(states: [CityViewModel])
    case secureCoreCountries(servers: [ServerViewModel])
    case servers(tier: ServerTier, servers: [ServerViewModel])
}

extension SearchResult {
    var title: String? {
        switch self {
        case let .countries(data):
            "\(Localizable.searchResultsCountries) (\(data.count))"
        case let .servers(tier: tier, servers: data):
            "\(tier.title) (\(data.count))"
        case let .secureCoreCountries(data):
            "\(Localizable.searchSecureCoreCountries) (\(data.count))"
        case let .cities(data):
            "\(Localizable.searchCities) (\(data.count))"
        case let .states(data):
            "\(Localizable.searchStates) (\(data.count))"
        case .upsell:
            nil
        }
    }

    var count: Int {
        switch self {
        case let .countries(data):
            data.count
        case let .servers(tier: _, servers: data):
            data.count
        case let .secureCoreCountries(data):
            data.count
        case let .cities(data):
            data.count
        case let .states(data):
            data.count
        case .upsell:
            1
        }
    }
}
