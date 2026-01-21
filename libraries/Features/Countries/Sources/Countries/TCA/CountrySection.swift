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
import Domain
import Foundation

@Reducer
struct CountrySectionFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: CountrySectionFeature.SectionID
        let type: SectionType
        var title: String?
        var rows: IdentifiedArrayOf<RowFeature.State>
        var hasInfoButton: Bool
        var serversFilter: CountrySectionFeature.ServerFilter
    }

    enum SectionType: Equatable {
        case gateway
        case countries
        case profiles
    }

    enum Action {
        case rows(IdentifiedActionOf<RowFeature>)
        case infoButtonTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .infoButtonTapped:
                print("Info button tapped for section: \(state.type)")
                return .none

            case .rows:
                return .none
            }
        }
        .forEach(\.rows, action: \.rows) {
            RowFeature()
        }
    }
}

@Reducer
struct RowFeature {
    @ObservableState
    enum State: Equatable, Identifiable {
        case country(CountryFeature.State)
        case profile(DefaultProfileFeature.State)
        case banner(BannerFeature.State)
        case offerBanner(OfferBannerFeature.State)

        public var id: String {
            switch self {
            case let .country(state):
                "country-\(state.id)"
            case let .profile(state):
                "profile-\(state.id)"
            case let .banner(state):
                "banner-\(state.id)"
            case let .offerBanner(state):
                "offerBanner-\(state.id)"
            }
        }
    }

    enum Action {
        case country(CountryFeature.Action)
        case profile(DefaultProfileFeature.Action)
        case banner(BannerFeature.Action)
        case offerBanner(OfferBannerFeature.Action)
    }

    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifCaseLet(\.country, action: \.country) {
                CountryFeature()
            }
            .ifCaseLet(\.profile, action: \.profile) {
                DefaultProfileFeature()
            }
            .ifCaseLet(\.banner, action: \.banner) {
                BannerFeature()
            }
            .ifCaseLet(\.offerBanner, action: \.offerBanner) {
                OfferBannerFeature()
            }
    }
}

extension CountrySectionFeature {
    enum SectionID: String, Equatable {
        case gateway
        case freeProfiles
        case paidCountries
        case allCountries
    }

    enum ServerFilter: Equatable {
        case none
        case restricted
        case `default`
    }
}
