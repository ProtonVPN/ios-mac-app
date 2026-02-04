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

import Dependencies

import CommonNetworking
import ComposableArchitecture
import Domain
import Foundation

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

        init(
            recommendedSection: CountryListSection,
            countriesSection: CountryListSection,
            focusedIndex: CountryListView.ItemCoordinate?
        ) {
            self.recommendedSection = recommendedSection
            self.countriesSection = countriesSection
            self.focusedIndex = focusedIndex
        }

        init() {
            @Dependency(\.serverRepository) var repository
            let allCountries: [CountryListItem] = repository
                .getGroups(filteredBy: [
                    .isNotUnderMaintenance,
                    .kind(.country),
                ], groupedBy: .serverType)
                .enumerated()
                .compactMap { index, group in
                    group.item(index: index, section: 1)
                }

            let countriesDictionary: [String: CountryListItem] = Dictionary(
                uniqueKeysWithValues: allCountries.map { ($0.code, $0) }
            )

            let recommendedCountries: [CountryListItem] = CountryListFeature.recommendedCountries
                .filter { countriesDictionary[$0]?.supportsStreaming == true }
                .map { CountryListItem(section: 0, row: 0, code: $0, supportsStreaming: true) }

            self.countriesSection = .init(
                name: "All countries",
                items: allCountries,
                sectionIndex: 1
            )
            self.recommendedSection = .init(
                name: "Recommended",
                items: [.fastest] + recommendedCountries,
                sectionIndex: 0
            )
        }
    }

    enum Action: BindableAction {
        case selectItem(ConnectableItem)
        case binding(BindingAction<State>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
    }
}

private extension ServerGroupInfo {
    func item(index: Int, section: Int) -> CountryListItem? {
        guard case let .country(code) = kind else { return nil }
        let row = Int(floor(Double(index) / Double(CountryListView.columnCount)))
        return CountryListItem(
            section: section,
            row: row,
            code: code,
            supportsStreaming: featureUnion.contains(.streaming)
        )
    }
}
