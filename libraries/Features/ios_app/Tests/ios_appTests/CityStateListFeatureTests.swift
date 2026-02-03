//
//  Created on 2026-02-03 by Pawel Jurczyk.
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
import DomainTestSupport
@testable import ios_app
import PersistenceTestSupport
import Testing

@Suite("City State List Feature Tests")
@MainActor
struct CityStateListFeatureTests {
    // MARK: - onAppear Tests

    @Test("onAppear sets loading state and reloads content")
    func onAppearSetsLoadingStateAndReloadsContent() async {
        let store = TestStore(initialState: .init(countryCode: "US")) {
            CityStateListFeature(selectedCountryCode: .init(get: { nil }, set: { _ in }))
        } withDependencies: {
            $0.serverRepository = .mockWithUSStates()
        }

        store.exhaustivity = .off

        await store.send(.didAppear)

        await store.receive(\.loaded) {
            $0.sectionTitle = "States (3)"
//            $0.listState = .loaded(.states([]))
        }
    }
}
