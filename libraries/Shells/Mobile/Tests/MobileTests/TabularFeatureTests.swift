//
//  Created on 28/07/2026.
//
//  Copyright (c) 2026 Proton AG
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
@testable import Mobile
import Testing

@Suite("Tabular shell")
struct TabularFeatureTests {
    @Test("Choosing a tab raises the sheet off its bar, and leaves it alone otherwise")
    @MainActor
    func tabSelectionRaisesTheSheet() async {
        let store = TestStore(initialState: TabularFeature.State(detent: .bar)) { TabularFeature() }
        // Assert the shell's own state and let the tab features' suites own theirs. Constructing them populates shared
        // storage of its own, which is their behavior to verify, not this suite's.
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabSelected) { $0.detent = .half }
        await store.send(.tabSelected)

        let raised = TestStore(initialState: TabularFeature.State(detent: .full)) { TabularFeature() }
        raised.exhaustivity = .off(showSkippedAssertions: false)
        await raised.send(.tabSelected)
    }

    @Test("The sheet follows the user's drag")
    @MainActor
    func detentChangesFollowTheSheet() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.detentChanged(.full)) { $0.detent = .full }
        await store.send(.detentChanged(.bar)) { $0.detent = .bar }
    }
}
