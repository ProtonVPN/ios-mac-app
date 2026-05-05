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
import Domain
import Persistence
import Strings

@Reducer
public struct SearchResultsDisplayFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var rows: IdentifiedArrayOf<SearchResultRow>
        public var searchText: String = ""
        public var isFreeTier: Bool = false

        public var numberOfCountries: Int {
            @Dependency(\.serverRepository) var repository
            return repository.countryCount()
        }
    }

    public enum Action: Equatable {
        // Selection actions
        case countrySelected(SearchCountryIndex)
        case countryConnectTapped(SearchCountryIndex)
        case citySelected(SearchCityIndex)
        case stateSelected(SearchCityIndex)
        case serverSelected(SearchServerIndex)

        // Upsell
        case showUpsell
        case showCountryUpsell(String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case showUpsell
            case showCountryUpsell(String)
            case navigateToCountry(String)
            case connectRequested(ConnectionSpec, UserInitiatedVPNChange.VPNTrigger?)
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .countrySelected(country):
                if state.isFreeTier {
                    return .send(.delegate(.showCountryUpsell(country.countryCode)))
                }
                return .send(.delegate(.navigateToCountry(country.countryCode)))

            case let .countryConnectTapped(country):
                if state.isFreeTier {
                    return .send(.delegate(.showCountryUpsell(country.countryCode)))
                }
                let spec = CityStateConnectionSpecFactory.makeSpec(location: .country(code: country.countryCode, order: .fastest))
                return .send(.delegate(.connectRequested(spec, .country)))

            case let .citySelected(city):
                if state.isFreeTier {
                    return .send(.delegate(.showCountryUpsell(city.countryCode)))
                }
                let spec = CityStateConnectionSpecFactory.makeSpec(location: .city(name: city.cityName, code: city.countryCode, order: .fastest))
                return .send(.delegate(.connectRequested(spec, .countriesCity)))

            case let .stateSelected(stateItem):
                if state.isFreeTier {
                    return .send(.delegate(.showCountryUpsell(stateItem.countryCode)))
                }
                let spec = CityStateConnectionSpecFactory.makeSpec(location: .state(
                    name: stateItem.cityName,
                    code: stateItem.countryCode,
                    order: .fastest
                ))
                return .send(.delegate(.connectRequested(spec, .countriesState)))

            case let .serverSelected(server):
                if server.isUsersTierTooLow {
                    return .send(.delegate(.showUpsell))
                }
                guard !server.underMaintenance else {
                    return .none
                }
                let spec = CityStateConnectionSpecFactory.makeSpec(
                    location: .exact(
                        server.tier == .free ? .free : .paid,
                        logicalID: server.id,
                        number: nil,
                        subregion: nil,
                        regionCode: server.exitCountryCode
                    )
                )
                return .send(.delegate(.connectRequested(spec, .countriesServer)))

            case .showUpsell:
                return .send(.delegate(.showUpsell))

            case let .showCountryUpsell(countryCode):
                return .send(.delegate(.showCountryUpsell(countryCode)))

            case .delegate:
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
    case state(SearchCityIndex)
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
        case let .state(state):
            "state-\(state.id)"
        case let .secureCoreCountry(state):
            "secureCoreCountry-\(state.id)"
        case let .server(state):
            "server-\(state.id)"
        }
    }
}
