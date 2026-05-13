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
import Connection
import Domain
import Foundation
import LegacyCommon
@testable import ProtonVPN
import Testing
import VPNShared
import VPNSharedTesting

@MainActor
struct SidebarFeatureTests {
    @Test("connect command forwards to connection feature")
    func connectCommandForwardsToConnectionFeature() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        let intent = ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: VpnProtocol.ike.protocolSupport
        )

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick)))
        await store.receive(.connection(.input(.connect(intent))))
    }

    @Test("disconnect command forwards to connection feature and runs completion")
    func disconnectCommandForwardsToConnectionFeatureAndRunsCompletion() async {
        await confirmation("completion called once") { called in
            let store = makeStore()
            await store.send(.connectionCommandReceived(.disconnect(.tray, completion: {
                called()
            })))
            await store.receive(.connection(.input(.disconnect)))
        }
    }

    @Test("retry command forwards to connection feature")
    func retryCommandForwardsToConnectionFeature() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        let intent = ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: VpnProtocol.ike.protocolSupport
        )

        await store.send(.connectionCommandReceived(.retry))
        await store.receive(.connection(.input(.connect(intent))))
    }

    @Test("apply settings command forwards to connection feature")
    func applySettingsCommandForwardsToConnectionFeature() async {
        let store = makeStore()
        let settings: Set<ConnectionFeatureChange.AgentFeature> = [.vpnAccelerator(true)]

        await store.send(.connectionCommandReceived(.applySettings(settings)))
        await store.receive(.connection(.input(.applySettings(settings))))
    }

    @Test("clear connection data command forwards to connection logout")
    func clearConnectionDataCommandForwardsToConnectionLogout() async {
        let store = makeStore()

        await store.send(.connectionCommandReceived(.clearConnectionData()))
        await store.receive(.connection(.input(.onLogout)))
    }

    @Test("command client broadcasts sent commands")
    func commandClientBroadcastsSentCommands() async {
        let client = SidebarConnectionCommandClient.liveValue
        let stream = await client.stream()
        await confirmation("command is received by stream listener") { commandReceived in
            var iterator = stream.makeAsyncIterator()
            client.send(.retry)
            guard let command = await iterator.next() else { return }
            if case .retry = command {
                commandReceived()
            }
        }
    }

    @Test("tab changed")
    func tabChanged() async {
        let store = makeStore()

        await store.send(.tabChanged(.profiles)) {
            $0.selectedTab = .profiles
        }
    }

    @Test("window end live resize persists map width")
    func windowEndLiveResizePersistsMapWidth() async throws {
        let defaults = try #require(UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)"))
        let store = makeStore(
            defaults: defaults
        )

        await store.send(.windowDidEndLiveResize(width: 1000, isFullscreen: false)) {
            $0.expandState = .expanded
            $0.mapWidth = 575
        }
        #expect(defaults.integer(forKey: AppConstants.UserDefaults.mapWidth) == 575)
    }

    @Test("vpn status updates overlay flag")
    func vpnStatusUpdatesOverlayFlag() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.vpnConnectionStatusUpdated(.connected(.defaultFastest, .mock())))
        await clock.advance(by: .seconds(3))
        await store.receive(\.connectedOverlayDelayElapsed) {
            $0.isLoadingOverlayVisible = false
        }
    }

    @Test("overlay dismissal by user hides overlay and allows next connection overlay")
    func overlayDismissedByUserHidesOverlayAndAllowsNextConnectionOverlay() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.vpnConnectionStatusUpdated(.connected(.defaultFastest, .mock())))

        await store.send(.overlayDismissedByUser) {
            $0.isLoadingOverlayVisible = false
        }

        await clock.advance(by: .seconds(3))

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.isLoadingOverlayVisible = true
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

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
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
    func viewDidLoadLoadsInitialMapWidth() async throws {
        let defaults = try #require(UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)"))
        defaults.set(720, forKey: AppConstants.UserDefaults.mapWidth)
        let store = makeStore(
            defaults: defaults
        )

        await store.send(.viewDidLoad) {
            $0.mapWidth = 720
        }
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.startObservingEvents)
    }

    @Test("connection delegate state updates shared connection and vpn status")
    func connectionDelegateStateUpdatesSharedConnectionAndVpnStatus() async {
        let store = makeStore()

        await store.send(.connection(.delegate(.stateChanged(.disconnected)))) {
            $0.$connectionState.withLock { $0 = .disconnected }
        }
        await store.receive(.vpnConnectionStatusUpdated(.disconnected)) {
            $0.$vpnConnectionStatus.withLock { $0 = .disconnected }
        }
        await store.receive(\.syncNATPortMappingState)
    }

    private func makeStore(
        environment: SidebarFeature.Environment = .init(
            sidebarWidth: 425,
            expandButtonWidth: 28,
            defaultMapWidth: 600
        ),
        defaults: UserDefaults = UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)")!,
        clock: TestClock<Duration>? = nil,
        sidebarConnectionCommandClient: SidebarConnectionCommandClient = .testValue
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
            $0.propertiesManager.connectionProtocol = .vpnProtocol(.ike)
            $0.propertiesManager.lastConnectionIntent = ConnectionSpec(location: .any(.fastest), features: [])
            $0.sidebarConnectionCommandClient = sidebarConnectionCommandClient
        }
    }
}
