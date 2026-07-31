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

        await store.send(.tabSelected(.home)) { $0.detent = .half }
        await store.send(.tabSelected(.home))

        var raisedState = TabularFeature.State()
        raisedState.tab = .countries
        raisedState.detent = .full
        let raised = TestStore(initialState: raisedState) { TabularFeature() }
        raised.exhaustivity = .off(showSkippedAssertions: false)
        await raised.send(.tabSelected(.profiles)) { $0.tab = .profiles }
    }

    @Test("A connect under the full sheet lowers it to half, and leaves lower stops alone")
    @MainActor
    func connectLowersTheFullSheet() async {
        var full = TabularFeature.State()
        full.detent = .full
        let store = TestStore(initialState: full) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.commands(.commandReceived(.connect(.defaultFastest, nil, .connectionCard)))) {
            $0.detent = .half
        }

        // Already at half: the connection is in view, so the sheet stays put.
        let atHalf = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        atHalf.exhaustivity = .off(showSkippedAssertions: false)
        await atHalf.send(.commands(.commandReceived(.connect(.defaultFastest, nil, .connectionCard))))
    }

    @Test("Touching the map through the half sheet collapses it to the bar")
    @MainActor
    func mapInteractionCollapsesTheHalfSheet() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.map(.mapMoved)) { $0.detent = .bar }
        // Already on the bar: gestures are plain map interactions and move nothing.
        await store.send(.map(.userPinTapped))
    }

    @Test("A page pushed beyond its root holds the sheet at full until it pops")
    @MainActor
    func deepPagesHoldTheSheetAtFull() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pageDepthChanged(true)) {
            $0.isPageDeep = true
            $0.detent = .full
        }
        // Nothing lowers it while deep: not a drag report, not a connect.
        await store.send(.detentChanged(.half))
        await store.send(.commands(.commandReceived(.connect(.defaultFastest, nil, .connectionCard))))

        await store.send(.pageDepthChanged(false)) { $0.isPageDeep = false }
        await store.send(.detentChanged(.half)) { $0.detent = .half }
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
