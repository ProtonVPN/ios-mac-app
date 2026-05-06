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
struct SidebarFeatureTests {
    @Test("connect command forwards to connect dependency")
    func connectCommandForwardsToDependency() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        await confirmation("connectToVPN called once") { connectToVPNCalled in
            let store = makeStore(
                connectToVPN: { receivedSpec, receivedProtocol, receivedTrigger in
                    #expect(receivedSpec == spec)
                    #expect(receivedProtocol == .smartProtocol)
                    #expect(receivedTrigger == .quick)
                    connectToVPNCalled()
                }
            )

            await store.send(.connectionCommandReceived(.connect(spec, .smartProtocol, .quick)))
        }
    }

    @Test("disconnect command forwards to disconnect dependency and runs completion")
    func disconnectCommandForwardsToDependencyAndRunsCompletion() async {
        await confirmation("disconnect and completion called", expectedCount: 2) { called in
            let store = makeStore(
                disconnectVPN: { trigger in
                    #expect(trigger == .tray)
                    called()
                }
            )

            await store.send(.connectionCommandReceived(.disconnect(.tray, completion: {
                called()
            })))
        }
    }

    @Test("connection commands are latest-wins")
    func connectionCommandsAreLatestWins() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        await confirmation("retry starts and previous connect effect exits", expectedCount: 2) { called in
            let store = makeStore(
                connectToVPN: { _, _, trigger in
                    switch trigger {
                    case .quick:
                        do {
                            try await Task.sleep(for: .seconds(10))
                        } catch {
                            #expect(error is CancellationError)
                        }
                        // Confirms the original effect fully exits after cancellation.
                        called()
                    case .auto:
                        called()
                    default:
                        break
                    }
                }
            )

            await store.send(.connectionCommandReceived(.connect(spec, nil, .quick)))
            await store.send(.connectionCommandReceived(.retry))
        }
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

    @Test("overlay dismissal by user hides overlay and allows next connection overlay")
    func overlayDismissedByUserHidesOverlayAndAllowsNextConnectionOverlay() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.appStateChanged(.preparingConnection)) {
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.appStateChanged(.connected(ServerDescriptor(username: "", address: ""))))

        await store.send(.overlayDismissedByUser) {
            $0.isLoadingOverlayVisible = false
        }

        await clock.advance(by: .seconds(3))

        await store.send(.appStateChanged(.preparingConnection)) {
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
    func viewDidLoadLoadsInitialMapWidth() async throws {
        let defaults = try #require(UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)"))
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
        clock: TestClock<Duration>? = nil,
        connectToVPN: @escaping @Sendable (ConnectionSpec, ConnectionProtocol?, UserInitiatedVPNChange.VPNTrigger?) async throws -> Void = { _, _, _ in },
        disconnectVPN: @escaping @Sendable (UserInitiatedVPNChange.VPNTrigger) async throws -> Void = { _ in },
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
            $0.connectToVPN = connectToVPN
            $0.disconnectVPN = disconnectVPN
            $0.sidebarConnectionCommandClient = sidebarConnectionCommandClient
        }
    }
}
