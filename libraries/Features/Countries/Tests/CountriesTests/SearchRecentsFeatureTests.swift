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

@Suite("SearchRecentsFeature Tests")
@MainActor
struct SearchRecentsFeatureReducerTests {
    @Test("onAppear loads recents from storage")
    func onAppearLoadsRecents() async {
        let store = TestStore(initialState: SearchRecentsFeature.State()) {
            SearchRecentsFeature()
        } withDependencies: {
            $0.searchStorageNew.get = { ["A", "B"] }
        }

        await store.send(.onAppear)
        await store.receive(\.load) {
            $0.recentSearches = ["A", "B"]
        }
    }

    @Test("clear presents confirmation alert")
    func clearPresentsAlert() async {
        let store = TestStore(
            initialState: SearchRecentsFeature.State(recentSearches: ["A"])
        ) {
            SearchRecentsFeature()
        }

        await store.send(.clear) {
            $0.alert = SearchRecentsFeature.clearAlert
        }
    }

    @Test("confirm clear clears storage and emits recentsCleared")
    func confirmClearClearsStateAndStorage() async {
        let didClear = LockIsolated(false)
        let store = TestStore(
            initialState: SearchRecentsFeature.State(recentSearches: ["A"], alert: SearchRecentsFeature.clearAlert)
        ) {
            SearchRecentsFeature()
        } withDependencies: {
            $0.searchStorageNew.clear = { didClear.withValue { $0 = true } }
        }

        await store.send(.clear)
        await store.send(.alert(.presented(.confirmClear))) {
            $0.alert = nil
            $0.recentSearches = []
        }
        await store.receive(\.recentsCleared)

        #expect(didClear.value)
    }
}
