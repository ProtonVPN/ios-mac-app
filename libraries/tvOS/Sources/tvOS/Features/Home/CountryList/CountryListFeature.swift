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

    /// More info about recommended countries selection:
    /// https://confluence.protontech.ch/pages/viewpage.action?pageId=128215858#Productmetricsforbusiness-Streaming
    static let recommendedCountries: [String] = ["US", "UK", "CA", "FR", "DE"]

    @ObservableState
    struct State: Equatable {
        var recommendedSection: CountryListSection
        var countriesSection: CountryListSection
        var focusedIndex: CountryListView.ItemCoordinate? = .fastest

        init() {
            @Dependency(\.serverRepository) var repository
            let allCountries = repository
                .getGroups(filteredBy: [
                    .isNotUnderMaintenance,
                    .kind(.country)
                ])
                .enumerated()
                .compactMap { (index, group) in
                    return group.item(index: index, section: 1)
                }

            let recommendedCountries: [CountryListItem] = {
                CountryListFeature.recommendedCountries
                    .filter { code in allCountries.contains { $0.code == code } } // be sure we can actually connect to that country
                    .map { CountryListItem(section: 0, row: 0, code: $0) }
            }()
            countriesSection = .init(name: "All countries",
                                     items: allCountries,
                                     sectionIndex: 1)
            recommendedSection = .init(name: "Recommended",
                                       items: [.fastest] + recommendedCountries,
                                       sectionIndex: 0)
        }
    }

    enum Action: BindableAction {
        case selectItem(CountryListItem)
        case binding(BindingAction<State>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
    }
}

private extension ServerGroupInfo {
    func item(index: Int, section: Int) -> CountryListItem? {
        guard case .country(let code) = kind else { return nil }
        let row = Int(floor(Double(index) / Double(CountryListView.columnCount)))
        return CountryListItem(section: section, row: row, code: code)
    }
}
