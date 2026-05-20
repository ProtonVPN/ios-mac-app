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

@testable import CertificateAuthentication
import Clocks
import ComposableArchitecture
@testable import Connection
@testable import CoreConnection
import Domain
@testable import ExtensionManager
import Foundation
import LegacyCommon
@testable import LocalAgent
import PaymentsShared
@testable import ProtonVPN
import Testing
import VPNAppCore
import VPNShared
import VPNSharedTesting

@MainActor
@Suite(.serialized)
struct SidebarFeatureTests {
    @Test("connect command forwards to connection feature")
    func connectCommandForwardsToConnectionFeature() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.isLoadingOverlayVisible = true
        }
        await store.receive(\.connection.input.connect) {
            $0.connection.reconnectionIntent = ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )
            $0.connection.connectionState = .connecting(.unresolved(ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )))
            $0.$connectionState.withLock {
                $0 = .connecting(.unresolved(ConnectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: .vpnProtocol(.ike),
                    acceptableProtocols: .ikev2
                )))
            }
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(spec, nil) }
        }
        await store.receive(\.connection.delegate.stateChanged.connecting.unresolved)
        await store.receive(\.vpnConnectionStatusUpdated.connecting) {
            $0.connectingOverlay.vpnConnectionStatus = .connecting(spec, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("disconnect command forwards to connection feature and runs completion")
    func disconnectCommandForwardsToConnectionFeatureAndRunsCompletion() async {
        await confirmation("completion called once") { called in
            let store = makeStore()
            await store.send(.connectionCommandReceived(.disconnect(.tray, completion: {
                called()
            })))
            await store.receive(\.connection.input.disconnect) {
                $0.connection.core.shouldDisconnectWhenAllowed = true
            }
        }
    }

    @Test("disconnect command is not dropped by following connect command")
    func disconnectCommandIsNotDroppedByFollowingConnectCommand() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.connectionCommandReceived(.disconnect(.auto))) {
            $0.connection.core.shouldDisconnectWhenAllowed = false
        }
        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.isLoadingOverlayVisible = true
        }

        await store.receive(\.connection.input.connect) {
            $0.connection.reconnectionIntent = ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )
            $0.connection.connectionState = .connecting(.unresolved(ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )))
            $0.$connectionState.withLock {
                $0 = .connecting(.unresolved(ConnectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: .vpnProtocol(.ike),
                    acceptableProtocols: .ikev2
                )))
            }
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(spec, nil) }
        }
    }

    @Test("retry command forwards to connection feature")
    func retryCommandForwardsToConnectionFeature() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        await store.send(.connectionCommandReceived(.retry)) {
            $0.isLoadingOverlayVisible = true
        }
        await store.receive(\.connection.input.connect) {
            $0.connection.reconnectionIntent = ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )
            $0.connection.connectionState = .connecting(.unresolved(ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )))
            $0.$connectionState.withLock {
                $0 = .connecting(.unresolved(ConnectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: .vpnProtocol(.ike),
                    acceptableProtocols: .ikev2
                )))
            }
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(spec, nil) }
        }
        await store.receive(\.connection.delegate.stateChanged.connecting.unresolved)
        await store.receive(\.vpnConnectionStatusUpdated.connecting) {
            $0.connectingOverlay.vpnConnectionStatus = .connecting(spec, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("connect command enforces p2p when port forwarding is enabled")
    func connectCommandEnforcesP2PWhenPortForwardingEnabled() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let p2pSpec = ConnectionSpec(location: .any(.fastest), features: [.p2p])
        let store = makeStore(portForwardingEnabled: true)

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.isLoadingOverlayVisible = true
        }
        await store.receive(\.connection.input.connect) {
            $0.connection.reconnectionIntent = ConnectionPreparationIntent(
                spec: p2pSpec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )
            $0.connection.connectionState = .connecting(.unresolved(ConnectionPreparationIntent(
                spec: p2pSpec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )))
            $0.$connectionState.withLock {
                $0 = .connecting(.unresolved(ConnectionPreparationIntent(
                    spec: p2pSpec,
                    connectionProtocol: .vpnProtocol(.ike),
                    acceptableProtocols: .ikev2
                )))
            }
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(p2pSpec, nil) }
        }
        await store.receive(\.connection.delegate.stateChanged.connecting.unresolved)
        await store.receive(\.vpnConnectionStatusUpdated.connecting) {
            $0.connectingOverlay.vpnConnectionStatus = .connecting(p2pSpec, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("apply settings command forwards to connection feature")
    func applySettingsCommandForwardsToConnectionFeature() async {
        let store = makeStore()
        let settings: Set<ConnectionFeatureChange.AgentFeature> = [.vpnAccelerator(true)]

        await store.send(.connectionCommandReceived(.applySettings(settings))) {
            $0.overlayPresentationPolicy = .suppressForInPlaceSettingsUpdate
        }
        await store.receive(\.connection.input.applySettings)
        await store.receive(\.connection.core.localAgent.setFeatures)
        await store.receive(\.connection.core.certAuth.refreshCertificate)
        await store.receive(\.connection.core.certAuth.refreshFinished.failure.cancelled)
    }

    @Test("in-place settings suppress connecting overlay, reconnect commands still show it")
    func inPlaceSettingsSuppressOverlayUntilReconnectCommand() async {
        let store = makeStore()
        store.exhaustivity = .off
        let settings: Set<ConnectionFeatureChange.AgentFeature> = [.portForwarding(true)]

        await store.send(.connectionCommandReceived(.applySettings(settings))) {
            $0.overlayPresentationPolicy = .suppressForInPlaceSettingsUpdate
        }

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $0.connectingOverlay.vpnConnectionStatus = .connecting(.defaultFastest, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
            $0.isLoadingOverlayVisible = false
        }

        await store.send(.connectionCommandReceived(.retry)) {
            $0.overlayPresentationPolicy = .automatic
            $0.isLoadingOverlayVisible = true
        }
    }

    @Test("refresh finished does not re-enable overlay for in-place updates")
    func refreshFinishedDoesNotReEnableOverlayForInPlaceUpdates() async {
        let store = makeStore()
        store.exhaustivity = .off
        let settings: Set<ConnectionFeatureChange.AgentFeature> = [.portForwarding(true)]

        await store.send(.connectionCommandReceived(.applySettings(settings))) {
            $0.overlayPresentationPolicy = .suppressForInPlaceSettingsUpdate
        }
        await store.receive(\.connection.input.applySettings)
        await store.receive(\.connection.core.localAgent.setFeatures)
        await store.receive(\.connection.core.certAuth.refreshCertificate)
        await store.receive(\.connection.core.certAuth.refreshFinished.failure.cancelled) {
            $0.overlayPresentationPolicy = .suppressForInPlaceSettingsUpdate
        }

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $0.connectingOverlay.vpnConnectionStatus = .connecting(.defaultFastest, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
            $0.isLoadingOverlayVisible = false
        }
    }

    @Test("clear connection data command forwards to connection logout")
    func clearConnectionDataCommandForwardsToConnectionLogout() async {
        let store = makeStore()

        await store.send(.connectionCommandReceived(.clearConnectionData()))
        await store.receive(\.connection.input.onLogout)
        await store.receive(\.connection.stopObserving)
        await store.receive(\.connection.core.handleLogout)
        await store.receive(\.connection.core.stopObserving)
        await store.receive(\.connection.core.tunnel.cleanup)
        await store.receive(\.connection.core.certAuth.clearEverything)
        await store.receive(\.connection.core.tunnel.stopObservingStateChanges)
        await store.receive(\.connection.core.localAgent.stopAllObservations)
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
        let connectedState = VPNConnectionActual.mock()
        #expect(store.state.vpnConnectionStatus == .resolving(nil, nil))

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $0.connectingOverlay.vpnConnectionStatus = .connecting(.defaultFastest, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.vpnConnectionStatusUpdated(.connected(.defaultFastest, connectedState))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connected(.defaultFastest, connectedState) }
            $0.connectingOverlay.vpnConnectionStatus = .connected(.defaultFastest, connectedState)
            $0.connectingOverlay.frozenStatus = .connected(.defaultFastest, connectedState)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await clock.advance(by: .seconds(3))
        await store.receive(\.connectedOverlayDelayElapsed) {
            $0.isLoadingOverlayVisible = false
        }
    }

    @Test("overlay dismissal by user hides overlay and allows next connection overlay")
    func overlayDismissedByUserHidesOverlayAndAllowsNextConnectionOverlay() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)
        let connectedState = VPNConnectionActual.mock()
        #expect(store.state.vpnConnectionStatus == .resolving(nil, nil))

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $0.connectingOverlay.vpnConnectionStatus = .connecting(.defaultFastest, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
            $0.isLoadingOverlayVisible = true
        }
        await store.send(.vpnConnectionStatusUpdated(.connected(.defaultFastest, connectedState))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connected(.defaultFastest, connectedState) }
            $0.connectingOverlay.vpnConnectionStatus = .connected(.defaultFastest, connectedState)
            $0.connectingOverlay.frozenStatus = .connected(.defaultFastest, connectedState)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }

        await store.send(.overlayDismissedByUser) {
            $0.isLoadingOverlayVisible = false
        }

        await clock.advance(by: .seconds(3))

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $0.connectingOverlay.vpnConnectionStatus = .connecting(.defaultFastest, nil)
            $0.connectingOverlay.frozenStatus = nil
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
            $0.isLoadingOverlayVisible = true
        }
    }

    @Test("connect command immediately shows overlay even without status transition")
    func connectCommandImmediatelyShowsOverlayEvenWithoutStatusTransition() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.overlayDismissedByUser)
        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.isLoadingOverlayVisible = true
        }
    }

    @Test("change server cooldown shows cantSkip upsell without connecting overlay")
    func changeServerCooldownShowsCantSkipUpsellWithoutOverlay() async {
        let until = Date(timeIntervalSince1970: 1_800_000_000)
        let duration: TimeInterval = 600
        let spec = ConnectionSpec(location: .any(.random), features: [])
        let store = makeStore(
            serverChangeAuthorizer: .init(
                serverChangeAvailability: {
                    .unavailable(until: until, duration: duration, exhaustedSkips: true)
                },
                registerServerChangeAtDate: { _ in }
            )
        )

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .changeServer))) {
            $0.pendingReconnectIntent = ConnectionPreparationIntent(
                spec: spec,
                connectionProtocol: .vpnProtocol(.ike),
                acceptableProtocols: .ikev2
            )
        }
        await store.receive(\.countriesSection.quickSettings.presentUpsell) {
            $0.countriesSection.quickSettings.destination = .upsell(
                .init(modalType: .cantSkip(
                    before: until,
                    totalDuration: duration,
                    longSkip: true
                ))
            )
        }

        #expect(store.state.isLoadingOverlayVisible == false)
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
        #expect(store.state.vpnConnectionStatus == .resolving(nil, nil))

        await store.send(.vpnConnectionStatusUpdated(.connecting(.defaultFastest, nil))) {
            $0.$vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            $0.connectingOverlay.vpnConnectionStatus = .connecting(.defaultFastest, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
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
        let store = makeStore(defaults: defaults)

        await store.send(.viewDidLoad) {
            $0.mapWidth = 720
            $0.connectingOverlay.vpnConnectionStatus = .resolving(nil, nil)
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await store.receive(\.connection.input.onLaunch)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
        await store.receive(\.startObservingEvents)
        await store.receive(\.connection.core.startObserving)
        await store.receive(\.connection.core.tunnel.startObservingStateChanges)
        await store.receive(\.connection.core.localAgent.startObservingEvents)
        await store.receive(\.connection.core.tunnel.tunnelStatusChanged.disconnected) {
            $0.connection.core.tunnel = .disconnected(nil)
        }
        await store.receive(\.connection.core.delegate.stateChanged) {
            $0.connection.connectionState = .disconnected
        }
        await store.receive(\.connection.delegate.stateChanged.disconnected)
        await store.receive(\.connection.delegate.stateChanged.disconnected)
        await store.receive(\.vpnConnectionStatusUpdated.disconnected) {
            $0.connectingOverlay.vpnConnectionStatus = .disconnected
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
        await store.receive(\.vpnConnectionStatusUpdated.disconnected)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
        await store.receive(\.syncPlutoniumState)
        await store.receive(\.syncNATPortMappingState)

        await store.send(.stopObservingEvents)
        await store.send(.connection(.stopObserving))
        await store.receive(\.connection.core.stopObserving)
        await store.receive(\.connection.core.tunnel.stopObservingStateChanges)
        await store.receive(\.connection.core.localAgent.stopAllObservations)
    }

    @Test("connection delegate state updates shared connection and vpn status")
    func connectionDelegateStateUpdatesSharedConnectionAndVpnStatus() async {
        let store = makeStore()
        #expect(store.state.vpnConnectionStatus == .resolving(nil, nil))

        await store.send(.connection(.delegate(.stateChanged(.disconnected)))) {
            $0.$connectionState.withLock { $0 = .disconnected }
            $0.$vpnConnectionStatus.withLock { $0 = .disconnected }
        }
        await store.receive(\.vpnConnectionStatusUpdated.disconnected) {
            $0.connectingOverlay.vpnConnectionStatus = .disconnected
            $0.connectingOverlay.selectedProtocol = .vpnProtocol(.ike)
            $0.connectingOverlay.killSwitchEnabled = false
            $0.connectingOverlay.intentionallyDisconnected = false
        }
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    private func makeStore(
        environment: SidebarFeature.Environment = .init(
            sidebarWidth: 425,
            expandButtonWidth: 28,
            defaultMapWidth: 600
        ),
        defaults: UserDefaults = UserDefaults(suiteName: "SidebarFeatureTests-\(UUID().uuidString)")!,
        clock: TestClock<Duration>? = nil,
        sidebarConnectionCommandClient: SidebarConnectionCommandClient = .testValue,
        portForwardingEnabled: Bool = false,
        serverChangeAuthorizer: ServerChangeAuthorizer = .availableValue
    ) -> TestStoreOf<SidebarFeature> {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus
        @Shared(.connectionState) var connectionState
        $vpnConnectionStatus.withLock { $0 = .resolving(nil, nil) }
        $connectionState.withLock { $0 = .resolving }

        return TestStore(initialState: SidebarFeature.State()) {
            SidebarFeature(
                environment: environment
            )
        } withDependencies: {
            if let clock {
                $0.continuousClock = clock
            }
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.tunnelManager = MockTunnelManager(connection: .init(status: .disconnected))
            $0.tunnelKeychain = TunnelKeychain(
                storeWireguardConfig: { _ in Data() },
                loadWireguardConfig: { Data() },
                clear: {}
            )
            $0.certificateRefreshClient = .init(
                refreshCertificateLocally: { _, _ in },
                refreshCertificate: { _ throws(CertificateRefreshError) in throw .cancelled },
                pushSelector: {}
            )
            $0.defaultsProvider = .init(getDefaults: { defaults })
            $0.propertiesManager.connectionProtocol = .vpnProtocol(.ike)
            $0.propertiesManager.lastConnectionIntent = ConnectionSpec(location: .any(.fastest), features: [])
            $0.sidebarConnectionCommandClient = sidebarConnectionCommandClient
            $0.portForwardingPropertyProvider.setPortForwarding(portForwardingEnabled)
            $0.serverChangeAuthorizer = serverChangeAuthorizer
        }
    }
}
