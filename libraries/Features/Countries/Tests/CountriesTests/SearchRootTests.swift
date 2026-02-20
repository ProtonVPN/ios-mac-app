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
import Testing

@Suite("SearchRoot Tests")
@MainActor
struct SearchRootTests {
    @Test("onAppear triggers preprocessing and loads placeholder")
    func onAppearLoadsPlaceholderWhenNoRecents() async {
        let store = TestStore(initialState: SearchRoot.State.loading([])) {
            SearchRoot()
        } withDependencies: {
            $0.searchStorageNew.get = { [] }
        }

        await store.send(.onAppear)
        await store.receive(\.performComputation)
        await store.receive(\.dataLoaded) {
            $0 = .loaded(.init(searchResults: .placeholder))
        }
    }

    @Test("onAppear initializes recent searches state when storage has data")
    func onAppearLoadsRecentSearchesState() async {
        let store = TestStore(initialState: SearchRoot.State.loading([])) {
            SearchRoot()
        } withDependencies: {
            $0.searchStorageNew.get = { ["uk"] }
        }

        await store.send(.onAppear)
        await store.receive(\.performComputation)
        await store.receive(\.dataLoaded) {
            $0 = .loaded(.init(searchResults: .recentSearches(.init())))
        }
    }

    @Test("performComputation is ignored when already loaded")
    func performComputationIgnoredWhenLoaded() async {
        let store = TestStore(initialState: SearchRoot.State.loaded(.init(searchResults: .placeholder))) {
            SearchRoot()
        }

        await store.send(.performComputation)
    }
}
