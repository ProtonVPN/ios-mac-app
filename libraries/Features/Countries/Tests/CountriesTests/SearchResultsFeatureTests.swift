//
//  Created on 19/02/2026 by Max Kupetskyi.
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
@testable import CountriesShared
import Strings
import Testing

@Suite("SearchResultsFeature Tests")
@MainActor
struct SearchResultsFeatureReducerTests {
    @Test("resultsDisplay action passes through parent reducer")
    func resultsDisplayActionPassThrough() async {
        let row = SearchResultRow.sectionHeader("Header")
        let store = TestStore(
            initialState: SearchResultsFeature.State.resultsDisplay(
                .init(rows: [row], searchText: "h")
            )
        ) {
            SearchResultsFeature()
        }

        await store.send(.resultsDisplay(.showUpsell))
    }

    @Test("recentSearches clear action is handled by child reducer")
    func recentSearchesChildReducerMutatesState() async {
        let store = TestStore(
            initialState: SearchResultsFeature.State.recentSearches(
                .init(recentSearches: ["One", "Two"])
            )
        ) {
            SearchResultsFeature()
        }

        await store.send(.recentSearches(.clear)) {
            $0 = .recentSearches(
                .init(
                    recentSearches: ["One", "Two"],
                    alert: SearchRecentsFeature.clearAlert
                )
            )
        }
    }
}
