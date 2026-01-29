//
//  Created on 09/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Dependencies
import Domain
import Foundation
import Localization

struct CityItem: Equatable, Hashable {
    let name: String
    let countryCode: String

    /// True if *any* servers in this city group are marked as having streaming support.
    /// When connecting to this item, use this property to determine whether to require the selected server
    /// to support streaming or not.
    let supportsStreaming: Bool

    var connectableItem: ConnectableItem {
        ConnectableItem(countryCode: countryCode, cityName: name, supportsStreaming: supportsStreaming)
    }
}

struct CountryListItem: Identifiable, Equatable, Hashable {
    var id: String
    let section: Int
    let row: Int
    let code: String
    let cities: [CityItem]

    /// True if *any* servers in this group are marked as having streaming support.
    /// When connecting to this item, use this property to determine whether to require the selected server
    /// to support streaming or not.
    let supportsStreaming: Bool

    var name: String {
        LocalizationUtility.default.countryName(forCode: code) ?? code
    }

    var connectableItem: ConnectableItem {
        ConnectableItem(countryCode: code, cityName: nil, supportsStreaming: supportsStreaming)
    }

    init(section: Int, row: Int, code: String, supportsStreaming: Bool) {
        self.id = "\(section)" + code
        self.section = section
        self.row = row
        self.code = code
        self.supportsStreaming = supportsStreaming

        // VPNAPPL-3331 - This work should be done lazily by the reducer once the user presses a country.
        @Dependency(\.serverRepository) var repository
        self.cities = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: code))],
                groupedBy: .cityName
            )
            .compactMap { group in
                guard let cityName = group.cityName else {
                    return nil
                }
                return CityItem(
                    name: cityName,
                    countryCode: code,
                    supportsStreaming: group.featureUnion.contains(.streaming)
                )
            }
    }
}

struct ConnectableItem: Equatable, Hashable {
    let countryCode: String
    let cityName: String?

    /// True if *any* servers in this city group are marked as having streaming support.
    /// When connecting to this item, use this property to determine whether to require the selected server
    /// to support streaming or not.
    let supportsStreaming: Bool

    var location: ConnectionSpec.Location {
        if let cityName {
            .city(name: cityName, code: countryCode, order: .fastest)
        } else if countryCode == "Fastest" {
            .any(.fastest)
        } else {
            .country(code: countryCode, order: .fastest)
        }
    }

    var connectionSpec: ConnectionSpec {
        ConnectionSpec(
            location: location,
            features: supportsStreaming ? [.streaming] : []
        )
    }
}

extension CountryListItem {
    static let fastest: Self = .init(section: 0, row: 0, code: "Fastest", supportsStreaming: true)
}

private extension ServerGroupInfo {
    var cityName: String? {
        guard case let .city(name, _) = kind else { return nil }
        return name
    }
}
