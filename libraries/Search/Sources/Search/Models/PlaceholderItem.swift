//
//  Created on 02.03.2022.
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

enum PlaceholderItem: CaseIterable {
    case countries
    case cities
    case usRegions
    case servers
}

extension PlaceholderItem {
    var title: String {
        switch self {
        case .countries:
            return Localizable.searchCountries
        case .cities:
            return Localizable.searchCities
        case .usRegions:
            return Localizable.searchUsRegions
        case .servers:
            return Localizable.searchServers
        }
    }

    var subtitle: String {
        switch self {
        case .countries:
            return Localizable.searchCountriesSample
        case .cities:
            return Localizable.searchCitiesSample
        case .usRegions:
            return Localizable.searchUsRegionsSample
        case .servers:
            return Localizable.searchServersSample
        }
    }
}
