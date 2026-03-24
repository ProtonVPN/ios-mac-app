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

import ComposableArchitecture
import Domain
import Testing

@testable import ProtonVPN

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
        var persistedWidth: Int?
        let store = makeStore(
            environment: .init(
                persistMapWidth: { width in
                    persistedWidth = width
                }
            )
        )

        await store.send(.windowDidEndLiveResize(width: 1000, isFullscreen: false)) {
            $0.expandState = .expanded
            $0.mapWidth = 575
        }
        #expect(persistedWidth == 575)
    }

    @Test("app state changed updates overlay flag")
    func appStateChangedUpdatesOverlayFlag() async {
        let store = makeStore()

        await store.send(.appStateChanged(.preparingConnection)) {
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.appStateChanged(.disconnected)) {
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

    private func makeStore(
        environment: SidebarFeature.Environment = .init(
            persistMapWidth: { _ in }
        )
    ) -> TestStoreOf<SidebarFeature> {
        TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature(
                quickSettingsEnvironment: .init(
                    performOptionSelection: { _, _, dismiss in dismiss() },
                    initialNetShieldStats: { .zero(enabled: false) }
                ),
                environment: environment,
                sidebarWidth: 425,
                expandButtonWidth: 28
            )
        }
    }
}
