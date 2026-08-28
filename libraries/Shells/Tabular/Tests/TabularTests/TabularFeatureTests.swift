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
import Foundation
import ModalsShared
import Persistence
import PersistenceTestSupport
@testable import Tabular
import Testing
import VPNAppCore
import VPNShared

@Suite("Tabular shell")
struct TabularFeatureTests {
    /// Runs `body` with an isolated app storage suite and a signed-in user, because the telemetry answer the
    /// question depends on is stored per user.
    @MainActor
    private func withTelemetryAnswer(
        stored: Bool?,
        needsReconsent: Bool,
        _ body: @MainActor () async -> Void
    ) async {
        let keychain = MockAuthKeychain()
        keychain.setMockUsername("test-user")
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            if let stored {
                defaults.set(String(stored), forKey: "TelemetryUsageDatatest-user")
            }
            defaults.set(needsReconsent, forKey: "TelemetryNeedsReconsenttest-user")
            await body()
        }
    }

    @Test("Starting the shell asks the telemetry question of a user whose answer the app wrote for them")
    @MainActor
    func startAsksTheTelemetryQuestionWhenNeeded() async {
        await withTelemetryAnswer(stored: false, needsReconsent: true) {
            let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.onStart) {
                $0.telemetryConsent = TelemetryConsentFeature.State()
            }
        }
    }

    @Test("Starting the shell asks nobody else")
    @MainActor
    func startAsksNothingOtherwise() async {
        await withTelemetryAnswer(stored: true, needsReconsent: false) {
            let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.onStart)
            #expect(store.state.telemetryConsent == nil)
        }
    }

    @Test("Confirming the telemetry question takes the sheet down")
    @MainActor
    func confirmingTakesTheSheetDown() async {
        await withTelemetryAnswer(stored: false, needsReconsent: true) {
            var state = TabularFeature.State()
            state.telemetryConsent = TelemetryConsentFeature.State()
            let store = TestStore(initialState: state) { TabularFeature() }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.telemetryConsent(.presented(.confirmButtonTapped)))
            await store.receive(\.telemetryConsent.dismiss) {
                $0.telemetryConsent = nil
            }
        }
    }

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
        await store.send(.map(.mapBackgroundTapped))
    }

    @Test("A page pushed beyond its root holds the sheet at full until it pops")
    @MainActor
    func deepPagesHoldTheSheetAtFull() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pageDepthChanged(tab: .home, isDeep: true)) {
            $0.deepTabs = [.home]
            $0.detent = .full
        }
        // Nothing lowers it while deep: not a drag report, not a connect.
        await store.send(.detentChanged(.half))
        await store.send(.commands(.commandReceived(.connect(.defaultFastest, nil, .connectionCard))))

        await store.send(.pageDepthChanged(tab: .home, isDeep: false)) { $0.deepTabs = [] }
        await store.send(.detentChanged(.half)) { $0.detent = .half }
    }

    @Test("Depth belongs to the visible tab")
    @MainActor
    func depthFollowsTheVisibleTab() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // Settings goes deep while visible, holding the sheet at full.
        await store.send(.tabSelected(.settings)) { $0.tab = .settings }
        await store.send(.pageDepthChanged(tab: .settings, isDeep: true)) {
            $0.deepTabs = [.settings]
            $0.detent = .full
        }

        // Another tab at its root releases the hold without disturbing the remembered depth.
        await store.send(.tabSelected(.home)) { $0.tab = .home }
        await store.send(.detentChanged(.half)) { $0.detent = .half }

        // Coming back to the deep tab needs the whole sheet again.
        await store.send(.tabSelected(.settings)) {
            $0.tab = .settings
            $0.detent = .full
        }

        // Leaving the deep tab keeps the sheet where it is; only the full-detent restriction is removed.
        await store.send(.tabSelected(.home)) { $0.tab = .home }
        // A report from a hidden tab's stack, like a programmatic pop, updates the set and nothing else.
        await store.send(.pageDepthChanged(tab: .settings, isDeep: false)) { $0.deepTabs = [] }
    }

    @Test("The sheet follows the user's drag")
    @MainActor
    func detentChangesFollowTheSheet() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.detentChanged(.full)) { $0.detent = .full }
        await store.send(.detentChanged(.bar)) { $0.detent = .bar }
    }

    @Test("Upsells reachable from every tab present from the shell rather than a page")
    @MainActor
    func shellUpsellsPresentFromTheShell() async {
        // Building the payments state resolves the modal's display copy, which reads the server repository.
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() } withDependencies: {
            $0.serverRepository = .empty()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // A free user tapping a location pin.
        await store.send(.map(.delegate(.showUpsell))) {
            $0.payments = .init(upsellModalType: .allCountries)
        }
        await store.send(.payments(.presented(.delegate(.dismissed)))) {
            $0.payments = nil
        }

        // The status banner's two upsell surfaces.
        await store.send(.connectionStatus(.delegate(.upsellTapped(.netshield)))) {
            $0.payments = .init(upsellModalType: .netShield)
        }
    }

    @Test("A failed intent resolution maps onto the upsell that lifts it")
    @MainActor
    func resolutionFailuresBecomeUpsells() async {
        let store = TestStore(initialState: TabularFeature.State()) { TabularFeature() } withDependencies: {
            $0.serverRepository = .empty()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.commands(.delegate(.intentResolutionFailed(.secureCoreUnavailable)))) {
            $0.payments = .init(upsellModalType: .secureCore)
        }
        await store.send(.commands(.delegate(.intentResolutionFailed(.specificCountryUnavailable(countryCode: "CH"))))) {
            $0.payments = .init(upsellModalType: .country(countryCode: "CH"))
        }
    }
}
