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
    @Reducer
    enum Path {
        case search
        case country(CountryFeature)
    }

    @Reducer
    enum Destination {
        // TODO: VPNAPPL-3313
//        case cityStateList
        case serversFeaturesInfo(ServersFeaturesInformationFeature)
        case serversStreamingFeaturesInfo(ServersStreamingFeaturesFeature)
    }

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        var sections: IdentifiedArrayOf<CountrySectionFeature.State>

        @Presents var destination: Destination.State?

        var enableViewToggle: Bool = true // TODO: Update
        var isSecureCore: Bool

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

        case secureCoreToggled

        // navigation path
        case path(StackActionOf<Path>)

        // sheets
        case destination(PresentationAction<Destination.Action>)

        // Section actions
        case sections(IdentifiedActionOf<CountrySectionFeature>)

        // Navigation
        case showFeaturesInfo
        case showServersStreamingFeaturesInfo
        case showSearch

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
            case .secureCoreToggled:
                return .none

            case .showFeaturesInfo:
                // differentiate between services/gateways
                state.destination = .serversFeaturesInfo(ServersFeaturesInformationFeature.State.servicesInfo)
                return .none

            case .showServersStreamingFeaturesInfo:
                state.destination =
                    .serversStreamingFeaturesInfo(ServersStreamingFeaturesFeature.State(countryName: "Country", streamingServices: IdentifiedArrayOf<StreamingServiceItem.State>())) // TODO: update
                return .none

            case .showSearch:
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

            case .sections:
                return .none

            case .binding:
                return .none

            case .connectRequested:
                return .none

            case .path:
                return .none

            case .destination:
                return .none
            }
        }
        .forEach(\.sections, action: \.sections) {
            CountrySectionFeature()
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
    }
}
