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

@Reducer
struct CountryListFeature {

    @ObservableState
    struct State: Equatable {
        var recommendedSection: CountryListSection?
        var countriesSection: CountryListSection?
    }

    enum Action {
        case selectItem(CountryListItem)
        case updateList
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .updateList:
                state.recommendedSection = CountryListSection(
                    name: "Recommended",
                    items: [fastest] + recommendedCountries
                )
                state.countriesSection = CountryListSection(
                    name: "All countries",
                    items: allCountries
                )
                return .none
            case .selectItem:
                return .none
            }
        }
    }

    private var allCountries: [CountryListItem] {
        @Dependency(\.serverRepository) var repository
        var counter = 0
        return repository
            .getGroups(filteredBy: [.isNotUnderMaintenance])
            .compactMap { group in
                defer { counter += 1 }
                return group.item(index: counter, section: 1)
            }
    }

    /// More info about recommended countries selection:
    /// https://confluence.protontech.ch/pages/viewpage.action?pageId=128215858#Productmetricsforbusiness-Streaming
    private var recommendedCountries: [CountryListItem] {
        let allCountries = self.allCountries
        return ["US", "UK", "CA", "FR", "DE"]
            .filter { code in allCountries.contains { $0.code == code } } // be sure we can actually connect to that country
            .map {
                CountryListItem(
                    section: 0,
                    row: 0,
                    code: $0
                )
            }
    }


    private var fastest: CountryListItem {
        CountryListItem(
            section: 0,
            row: 0,
            code: "Fastest"
        )
    }
}

private extension ServerGroupInfo {
    func item(index: Int, section: Int) -> CountryListItem? {
        guard case .country(let code) = kind else { return nil }

        return CountryListItem(
            section: section,
            row: Int(floor(Double(index) / Double(CountryListView.columnCount))),
            code: code
        )
    }
}
