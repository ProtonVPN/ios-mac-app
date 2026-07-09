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
import Foundation
import Testing

@Suite("SearchRoot Tests")
@MainActor
struct SearchRootTests {
    @Test("onAppear triggers preprocessing and loads placeholder")
    func onAppearLoadsPlaceholderWhenNoRecents() async throws {
        let suiteName = "SearchRootTests-\(#function)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.recentSearches) var recentSearches
            $recentSearches.withLock { $0 = [] }

            let store = TestStore(initialState: SearchRoot.State.loading([])) {
                SearchRoot()
            }

            await store.send(.onAppear)
            await store.receive(\.performComputation)
            await store.receive(\.dataLoaded) {
                $0 = .loaded(.init(searchResults: .placeholder))
            }
        }
    }

    @Test("onAppear initializes recent searches state when storage has data")
    func onAppearLoadsRecentSearchesState() async throws {
        let suiteName = "SearchRootTests-\(#function)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.recentSearches) var recentSearches
            $recentSearches.withLock { $0 = ["uk"] }

            let store = TestStore(initialState: SearchRoot.State.loading([])) {
                SearchRoot()
            }

            await store.send(.onAppear)
            await store.receive(\.performComputation)
            await store.receive(\.dataLoaded) {
                $0 = .loaded(.init(searchResults: .recentSearches(.init())))
            }
        }
    }

    @Test("performComputation is ignored when already loaded")
    func performComputationIgnoredWhenLoaded() async {
        let store = TestStore(initialState: SearchRoot.State.loaded(.init(searchResults: .placeholder))) {
            SearchRoot()
        }

        await store.send(.performComputation)
    }

    @Test("search delegate bubbles to root delegate")
    func searchDelegateBubblesToRoot() async {
        let store = TestStore(initialState: .loaded(.init(searchResults: .placeholder))) {
            SearchRoot()
        }
        store.exhaustivity = .off

        await store.send(.loaded(.delegate(.showUpsell)))
    }
}
