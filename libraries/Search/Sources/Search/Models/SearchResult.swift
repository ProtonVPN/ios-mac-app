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

enum SearchResult {
    case upsell
    case countries(countries: [CountryViewModel])
    case secureCoreCountries(servers: [ServerViewModel])
    case servers(tier: ServerTier, servers: [ServerViewModel])
}

extension SearchResult {
    var title: String? {
        switch self {
        case let .countries(data):
            return "\(LocalizedString.searchResultsCountries) (\(data.count))"
        case let .servers(tier: tier, servers: data):
            return "\(tier.title) (\(data.count))"
        case let .secureCoreCountries(data):
            return "\(LocalizedString.searchSecureCoreCountries) (\(data.count))"
        case .upsell:
            return nil
        }
    }

    var count: Int {
        switch self {
        case let .countries(data):
            return data.count
        case let .servers(tier: _, servers: data):
            return data.count
        case let .secureCoreCountries(data):
            return data.count
        case .upsell:
            return 1
        }
    }
}
