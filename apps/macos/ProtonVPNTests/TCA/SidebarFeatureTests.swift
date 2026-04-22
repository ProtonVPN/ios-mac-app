//
//  Created on 24/03/2026 by Max Kupetskyi.
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

import Clocks
import ComposableArchitecture
import Domain
import Foundation
import LegacyCommon
@testable import ProtonVPN
import Testing

@MainActor
@Suite
struct SidebarFeatureTests {
    @Test("tab changed")
    func tabChanged() async {
        let store = makeStore()

        await store.send(.tabChanged(.profiles)) {
            $0.selectedTab = .profiles
        }
    }

    @Test("window end live resize persists map width")
    func windowEndLiveResizePersistsMapWidth() async {
        let defaults = UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)")!
        let store = makeStore(
            defaults: defaults
        )

        await store.send(.windowDidEndLiveResize(width: 1000, isFullscreen: false)) {
            $0.expandState = .expanded
            $0.mapWidth = 575
        }
        #expect(defaults.integer(forKey: AppConstants.UserDefaults.mapWidth) == 575)
    }

    @Test("app state changed updates overlay flag")
    func appStateChangedUpdatesOverlayFlag() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.appStateChanged(.preparingConnection)) {
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.appStateChanged(.connected(ServerDescriptor(username: "", address: ""))))
        await clock.advance(by: .seconds(3))
        await store.receive(\.connectedOverlayDelayElapsed) {
            $0.isLoadingOverlayVisible = false
        }
    }

    @Test("fullscreen and occlusion flags")
    func fullscreenAndOcclusionFlags() async {
        let store = makeStore()

        await store.send(.windowWillEnterFullScreen) {
            $0.isFullscreen = true
        }
        await store.send(.windowWillExitFullScreen) {
            $0.isFullscreen = false
        }
        await store.send(.occlusionStateChanged(isVisible: false)) {
            $0.isOccludedVisible = false
        }
    }

    @Test("overlay presentation requires loading and visible app")
    func overlayPresentationRequiresLoadingAndVisibleApp() async {
        let store = makeStore()

        await store.send(.appStateChanged(.preparingConnection)) {
            $0.isLoadingOverlayVisible = true
        }
        #expect(store.state.shouldPresentLoadingOverlay)

        await store.send(.occlusionStateChanged(isVisible: false)) {
            $0.isOccludedVisible = false
        }
        #expect(!store.state.shouldPresentLoadingOverlay)

        await store.send(.occlusionStateChanged(isVisible: true)) {
            $0.isOccludedVisible = true
        }
        #expect(store.state.shouldPresentLoadingOverlay)
    }

    @Test("expand button tapped toggles expand state")
    func expandButtonTappedTogglesExpandState() async {
        let store = makeStore()

        await store.send(.expandButtonTapped) {
            $0.expandState = .expanded
        }
        await store.send(.expandButtonTapped) {
            $0.expandState = .compact
        }
    }

    @Test("countries delegate routes to sidebar")
    func countriesDelegateRoutesToSidebar() async {
        let store = makeStore()

        await store.send(.countriesSection(.delegate(.openProfilesTab))) {
            $0.selectedTab = .profiles
        }
    }

    @Test("loads map with initial width")
    func viewDidLoadLoadsInitialMapWidth() async {
        let defaults = UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)")!
        defaults.set(720, forKey: AppConstants.UserDefaults.mapWidth)
        let store = makeStore(
            defaults: defaults
        )

        await store.send(.viewDidLoad) {
            $0.mapWidth = 720
        }
        await store.receive(\.startObservingEvents)
    }

    private func makeStore(
        environment: SidebarFeature.Environment = .init(
            appStateChanged: { AsyncStream { continuation in continuation.finish() } },
            sidebarWidth: 425,
            expandButtonWidth: 28,
            defaultMapWidth: 600
        ),
        defaults: UserDefaults = UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)")!,
        clock: TestClock<Duration>? = nil
    ) -> TestStoreOf<SidebarFeature> {
        TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature(
                quickSettingsEnvironment: .init(
                    performOptionSelection: { _, _, dismiss in dismiss() },
                    initialNetShieldStats: { .zero(enabled: false) }
                ),
                environment: environment
            )
        } withDependencies: {
            if let clock {
                $0.continuousClock = clock
            }
            $0.defaultsProvider = .init(getDefaults: { defaults })
        }
    }
}
