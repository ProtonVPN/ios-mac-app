//
//  Created on 2026-02-10 by Pawel Jurczyk.
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

import AppIntents
import Dependencies
import Localization
import Persistence

public struct CountryEntity: AppEntity, Identifiable {
    public let id: String

    let title: String

    // Visual representation e.g. in the dropdown, when selecting the entity.
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    // Placeholder whenever it needs to present your entity’s type onscreen.
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Country"

    public static let defaultQuery = CountriesQuery()
}

public struct CountriesQuery: EntityQuery {
    public init() {}

    public func suggestedEntities() async throws -> [CountryEntity] {
        @Dependencies.Dependency(\.serverRepository) var repository

        let countries = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country)],
                groupedBy: .serverType
            )

        return countries
            .compactMap { group in
                if case let .country(code) = group.kind,
                   let translatedCountryName = LocalizationUtility.default.countryName(forCode: code) {
                    return CountryEntity(id: code, title: translatedCountryName)
                }
                return nil
            }
    }

    // Find Entity by id to bridge the Shortcuts Entity to your App
    public func entities(for identifiers: [String]) async throws -> [CountryEntity] {
        identifiers.compactMap {
            if let translatedCountryName = LocalizationUtility.default.countryName(forCode: $0) {
                return CountryEntity(id: $0, title: translatedCountryName)
            }
            return nil
        }
    }
}
