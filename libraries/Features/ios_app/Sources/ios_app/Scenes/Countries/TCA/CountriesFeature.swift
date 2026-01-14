//
//  Created on 08/01/2026 by Max Kupetskyi.
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
import Domain
import VPNAppCore

@Reducer
struct CountriesFeature {
    @ObservableState
    struct State: Equatable {
        var showGatewayInfo = false
        var sections: IdentifiedArrayOf<CountrySectionFeature.State>

        // Search data to use in Search module
        var searchData: IdentifiedArrayOf<CountryFeature.State> {
            let countryStates = sections.flatMap { section -> [CountryFeature.State] in
                section.rows.compactMap { row -> CountryFeature.State? in
                    guard case let .country(countryState) = row else { return nil }
                    return countryState
                }
            }
            return IdentifiedArray(uniqueElements: countryStates)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)

        // Section actions
        case section(IdentifiedActionOf<CountrySectionFeature>)

        // Gateway info
        case showGatewayInfo
        case hideGatewayInfo

        // Upsell actions
        case presentAllCountriesUpsell
        case presentCountryUpsell(String)
        case presentFreeConnectionsInfo

        case connectRequested(ConnectionSpec)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .showGatewayInfo:
                state.showGatewayInfo = true
                return .none

            case .hideGatewayInfo:
                state.showGatewayInfo = false
                return .none

            case .presentAllCountriesUpsell:
                print("Present AllCountriesUpsellAlert")
                return .none

            case let .presentCountryUpsell(countryCode):
                print("Present CountryUpsellAlert for: \(countryCode)")
                return .none

            case .presentFreeConnectionsInfo:
                print("Present FreeConnectionsAlert")
                return .none

            case .section:
                return .none

            case .binding:
                return .none

            case .connectRequested:
                return .none
            }
        }
        .forEach(\.sections, action: \.section) {
            CountrySectionFeature()
        }
    }
}
