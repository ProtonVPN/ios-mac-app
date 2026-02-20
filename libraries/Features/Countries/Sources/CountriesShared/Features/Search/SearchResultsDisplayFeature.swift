//
//  Created on 27/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import Persistence
import Strings

@Reducer
public struct SearchResultsDisplayFeature {
    @ObservableState
    public struct State: Equatable {
        public var rows: IdentifiedArrayOf<SearchResultRow>
        public var searchText: String = ""

        public var numberOfCountries: Int {
            @Dependency(\.serverRepository) var repository
            return repository.countryCount()
        }
    }

    public enum Action {
        // Selection actions
        case countrySelected(SearchCountryIndex)
        case citySelected(SearchCityIndex)
        case serverSelected(SearchServerIndex)

        // Upsell
        case showUpsell
        case showCountryUpsell(String)
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case let .countrySelected(country):
                print("countrySelected: \(country.name)")
                // TODO: Navigate to country detail or connect
                // TODO: Check if user tier is too low and show upsell
                return .none

            case let .citySelected(city):
                print("citySelected: \(city.translatedCityName ?? city.cityName)")
                // TODO: Navigate to city detail or connect
                return .none

            case let .serverSelected(server):
                print("serverSelected: \(server.serverName)")
                // TODO: Connect to specific server
                // TODO: check if it's under maintenance
                return .none

            case .showUpsell:
                print("showUpsell")
                // TODO: Show general upsell modal
                return .none

            case let .showCountryUpsell(countryCode):
                print("showCountryUpsell: \(countryCode)")
                // TODO: Show country-specific upsell modal
                return .none
            }
        }
    }
}

public enum SearchResultRow: Equatable, Identifiable, Sendable {
    case sectionHeader(String)
    case upsell
    case country(SearchCountryIndex)
    case city(SearchCityIndex)
    case secureCoreCountry(SearchServerIndex)
    case server(SearchServerIndex)

    public var id: String {
        switch self {
        case let .sectionHeader(title):
            "header-\(title)"
        case .upsell:
            "upsell"
        case let .country(state):
            "country-\(state.id)"
        case let .city(state):
            "city-\(state.id)"
        case let .secureCoreCountry(state):
            "secureCoreCountry-\(state.id)"
        case let .server(state):
            "server-\(state.id)"
        }
    }
}
