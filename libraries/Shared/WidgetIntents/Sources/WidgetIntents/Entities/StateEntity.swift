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

public struct StateEntity: AppEntity, Identifiable {
    public let id: String

    let name: String
    let countryCode: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: .init(stringLiteral: name))
    }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "State"

    public static let defaultQuery = StateQuery()
}

public struct StateQuery: EntityQuery {
    @IntentParameterDependency<ConnectToRegionIntent>(\.$country) var country

    public init() {}

    public func suggestedEntities() async throws -> [StateEntity] {
        @Dependencies.Dependency(\.serverRepository) var repository

        let countryCode = country?.country.id
        let countries = repository
            .getGroups(
                filteredBy: [.isNotUnderMaintenance, .kind(.country(code: countryCode))],
                groupedBy: .stateName
            )

        let states = countries
            .compactMap { group in
                if case let .state(name, code) = group.kind {
                    return StateEntity(id: code + "_" + name, name: name, countryCode: code)
                }
                return nil
            }

        return states
    }

    public func entities(for identifiers: [String]) async throws -> [StateEntity] {
        identifiers.map {
            let idParts = $0.components(separatedBy: "_")
            let code = idParts.first ?? ""
            let name = idParts.last ?? ""
            return StateEntity(id: $0, name: name, countryCode: code)
        }
    }
}
