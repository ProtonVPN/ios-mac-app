//
//  Created on 23/05/2024.
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
import Foundation
import CommonNetworking
import Domain
import Localization

struct HomeListSection: Equatable, Hashable, Identifiable {
    let name: String
    let items: [HomeListItem]
    var id: String { name }
}

struct HomeListItem: Identifiable, Equatable, Hashable {
    let id: String = UUID().uuidString

    let row: Int
    let code: String
    let name: String
}

@Reducer
struct CountryListFeature {

    @ObservableState
    struct State: Equatable {
        var recommendedSection: HomeListSection?
        var countriesSection: HomeListSection?
    }

    enum Action {
        case onAppear
        case selectItem(HomeListItem)
        case updateList
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [listIsEmpty = state.countriesSection == nil] send in
                    @Dependency(\.serverRepository) var repository
                    @Dependency(\.logicalsRefresher) var refresher
                    if repository.isEmpty || refresher.shouldRefreshLogicals() {
                        try await refresher.refreshLogicalsIfNeeded()
                        await send(.updateList)
                    } else if listIsEmpty {
                        await send(.updateList)
                    }
                } catch: { error, action in
                    print("loadLogicals error: \(error)")
                    // TODO: error handling
                }
            case .updateList:
                state.recommendedSection = HomeListSection(
                    name: "Recommended",
                    items: [fastest] + recommendedCountries
                )
                state.countriesSection = HomeListSection(
                    name: "All countries",
                    items: allCountries
                )
                return .none
            case .selectItem:
                return .none
            }
        }
    }

    private var allCountries: [HomeListItem] {
        @Dependency(\.serverRepository) var repository
        var counter = 0
        return repository
            .getGroups(filteredBy: [.isNotUnderMaintenance])
            .compactMap { group in
                defer { counter += 1 }
                return group.item(index: counter)
            }
    }

    /// More info about recommended countries selection:
    /// https://confluence.protontech.ch/pages/viewpage.action?pageId=128215858#Productmetricsforbusiness-Streaming
    private var recommendedCountries: [HomeListItem] {
        let allCountries = self.allCountries
        return ["US", "UK", "CA", "FR", "DE"]
            .filter { code in allCountries.contains { $0.code == code } } // be sure we can actually connect to that country
            .map {
                HomeListItem(
                    row: 0,
                    code: $0,
                    name: LocalizationUtility.default.countryName(forCode: $0) ?? ""
                )
            }
    }


    private var fastest: HomeListItem {
        HomeListItem(
            row: 0,
            code: "Fastest",
            name: "Fastest"
        )
    }
}

private extension ServerGroupInfo {
    func item(index: Int) -> HomeListItem? {
        guard case .country(let code) = kind else { return nil }

        return HomeListItem(
            row: Int(floor(Double(index) / Double(CountryListView.columnCount))),
            code: code,
            name: LocalizationUtility.default.countryName(forCode: code) ?? ""
        )
    }
}
