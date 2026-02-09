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
import Dependencies

public enum SearchResult: Equatable, Identifiable {
    case upsell
    case countries([CountryFeature.State])
    case cities([CityFeature.State])
    case secureCoreCountries([ServerItemFeature.State])
    case servers(tier: ServerTier, servers: [ServerItemFeature.State])

    public var id: String {
        switch self {
        case .upsell:
            "upsell"
        case .countries:
            "countries"
        case .cities:
            "cities"
        case .secureCoreCountries:
            "secureCoreCountries"
        case let .servers(tier, _):
            "servers-\(tier.rawValue)"
        }
    }

    public var count: Int {
        switch self {
        case .upsell:
            1
        case let .countries(data):
            data.count
        case let .cities(data):
            data.count
        case let .secureCoreCountries(data):
            data.count
        case let .servers(_, servers):
            servers.count
        }
    }
}

@Reducer
public struct SearchResultsDisplayFeature {
    @ObservableState
    public struct State: Equatable {
        var searchResults: [SearchResult]
    }

    public enum Action {
        // Selection actions
        case countrySelected(CountryFeature.State)
        case citySelected(CityFeature.State)
        case serverSelected(ServerItemFeature.State)

        // Upsell
        case showUpsell
        case showCountryUpsell(String)
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case let .countrySelected(country):
                print("countrySelected: \(country.description)")
                // TODO: Navigate to country detail or connect
                // TODO: Check if user tier is too low and show upsell
                return .none

            case let .citySelected(city):
                print("citySelected: \(city.displayName)")
                // TODO: Navigate to city detail or connect
                return .none

            case let .serverSelected(server):
                print("serverSelected: \(server.description)")
                // TODO: Connect to specific server
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
