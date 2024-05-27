//
//  Created on 25/04/2024.
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

import ComposableArchitecture

@Reducer
struct MainFeature {

    enum Tab { case home, search, settings }

    @ObservableState
    struct State: Equatable {
        var currentTab: Tab = .home
        var countryList = CountryListFeature.State(sections: [
            HomeListSection(
                name: "Recommended",
                items: [
                    HomeListItem(code: "Fastest", name: "Fastest", isConnected: false),
                    HomeListItem(code: "US", name: "United States", isConnected: false),
                    HomeListItem(code: "GB", name: "Great Britain", isConnected: false),
                    HomeListItem(code: "DE", name: "Germany", isConnected: true),
                    HomeListItem(code: "JP", name: "Japan", isConnected: false),
                    HomeListItem(code: "FR", name: "France", isConnected: false),
                ]),
            HomeListSection(
                name: "All countries",
                items: [
                    HomeListItem(code: "Fastest", name: "Fastest", isConnected: false),
                    HomeListItem(code: "LT", name: "Lithuania", isConnected: false),
                    HomeListItem(code: "PL", name: "Poland", isConnected: false),
                    HomeListItem(code: "CH", name: "Switzerland", isConnected: false),
                    HomeListItem(code: "US", name: "United States", isConnected: false),
                    HomeListItem(code: "CA", name: "Canada", isConnected: false),
                    HomeListItem(code: "FR", name: "France", isConnected: false),
                    HomeListItem(code: "BE", name: "Belgium", isConnected: false),
                    HomeListItem(code: "DE", name: "Germany", isConnected: true),
                    HomeListItem(code: "NL", name: "Netherlands", isConnected: false),
                    HomeListItem(code: "GB", name: "Great Britain", isConnected: false),
                    HomeListItem(code: "CZ", name: "Czechia", isConnected: false),
                    HomeListItem(code: "CR", name: "Croatia", isConnected: false),
                    HomeListItem(code: "IT", name: "Italy", isConnected: false),
                    HomeListItem(code: "GR", name: "Greece", isConnected: false),
                    HomeListItem(code: "AR", name: "Argentina", isConnected: false),
                    HomeListItem(code: "AU", name: "Australia", isConnected: false),
                    HomeListItem(code: "NZ", name: "New Zealand", isConnected: false),
                    HomeListItem(code: "BG", name: "Bulgaria", isConnected: false),
                    HomeListItem(code: "CO", name: "Colombia", isConnected: false),
                    HomeListItem(code: "DK", name: "Denmark", isConnected: false),
                    HomeListItem(code: "SE", name: "Sweden", isConnected: false),
                    HomeListItem(code: "FI", name: "Finland", isConnected: false),
                    HomeListItem(code: "NO", name: "Norway", isConnected: false),
                    HomeListItem(code: "IS", name: "Island", isConnected: false),
                    HomeListItem(code: "LV", name: "Latvia", isConnected: false),
                    HomeListItem(code: "EE", name: "Estonia", isConnected: false),
                ]),
        ])
        var settings: SettingsFeature.State = .init()
    }

    enum Action {
        case selectTab(Tab)
        case countryList(CountryListFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.countryList, action: \.countryList) {
            CountryListFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .selectTab(let tab):
                state.currentTab = tab
                return .none
            case .settings:
                return .none
            case .countryList(_):
                return .none
            }
        }
    }
}
