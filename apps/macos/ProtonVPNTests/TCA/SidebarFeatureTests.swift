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
@testable import Connection
@testable import CoreConnection
import Domain
import Ergonomics
@testable import ExtensionManager
@testable import ExtensionSync
import Foundation
@testable import Hermes
import NATPortMapping
import os
import PaymentsShared
@testable import ProtonVPN
import Strings
import Testing
import VPNAppCore
import VPNShared

@MainActor
@Suite(.serialized)
struct SidebarFeatureTests {
    @Test("connect command forwards to connection feature")
    func connectCommandForwardsToConnectionFeature() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        store.exhaustivity = .off // the connection layer runs for real here

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: spec)
        }
        await store.receive(\.connection.input.connect, ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: .ikev2
        ))
        await store.receive(\.connection.delegate.stateChanged.connecting)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("disconnect command forwards to connection feature and runs completion when already disconnected")
    func disconnectCommandForwardsToConnectionFeatureAndRunsCompletion() async {
        await confirmation("completion called once") { called in
            let store = makeStore(connectionState: .disconnected)
            store.exhaustivity = .off

            await store.send(.connectionCommandReceived(.disconnect(.tray, completion: {
                called()
            })))
            await store.receive(\.connection.input.disconnect)
            await store.receive(\.connection.tunnel.disconnect)
        }
    }

    @Test("disconnect command queues completion until disconnected delegate fires")
    func disconnectCommandQueuesCompletionUntilDisconnectedDelegate() async {
        await confirmation("completion called once") { called in
            let store = makeStore()
            store.exhaustivity = .off

            // connectionState defaults to .resolving in makeStore, so the tunnel is not down yet and the completion
            // waits in the queue.
            await store.send(.connectionCommandReceived(.disconnect(.tray, completion: {
                called()
            })))
            await store.receive(\.connection.input.disconnect)

            // The queue drains once the connection layer reports the tunnel really is down.
            let reportDisconnected = await store.send(.connection(.delegate(.stateChanged(.disconnected))))
            await reportDisconnected.finish()
        }
    }

    @Test("disconnect command is not dropped by following connect command")
    func disconnectCommandIsNotDroppedByFollowingConnectCommand() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.connectionCommandReceived(.disconnect(.auto)))
        await store.receive(\.connection.input.disconnect)

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: spec)
        }
        await store.receive(\.connection.input.connect, ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: .ikev2
        ))
    }

    @Test("disconnect command hides overlay immediately")
    func disconnectCommandHidesOverlayImmediately() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.connectionCommandReceived(.connect(.defaultFastest, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: .defaultFastest)
        }
        await store.send(.connectionCommandReceived(.disconnect(.auto))) {
            $0.overlayState = .hidden
        }
    }

    @Test("retry command forwards to connection feature")
    func retryCommandForwardsToConnectionFeature() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        store.exhaustivity = .off // the connection layer runs for real here; see the note on the suite

        await store.send(.connectionCommandReceived(.retry)) {
            $0.overlayState = .connecting(spec: spec)
        }
        await store.receive(\.connection.input.connect, ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: .ikev2
        ))
        await store.receive(\.connection.delegate.stateChanged.connecting)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("connect command enforces p2p when port forwarding is enabled")
    func connectCommandEnforcesP2PWhenPortForwardingEnabled() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let p2pSpec = ConnectionSpec(location: .any(.fastest), features: [.p2p])
        let store = makeStore(portForwardingEnabled: true)
        store.exhaustivity = .off // the connection layer runs for real here; see the note on the suite

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: p2pSpec)
        }
        await store.receive(\.connection.input.connect, ConnectionPreparationIntent(
            spec: p2pSpec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: .ikev2
        ))
        await store.receive(\.connection.delegate.stateChanged.connecting)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("apply settings command forwards to connection feature")
    func applySettingsCommandForwardsToConnectionFeature() async {
        let store = makeStore()
        let settings: Set<ConnectionFeatureChange> = [.agent(.vpnAccelerator(true))]

        await store.send(.connectionCommandReceived(.applySettings(settings))) {
            $0.overlayState = .suppressed
        }
        await store.receive(\.connection.input.applySettings)
        await store.receive(\.connection.tunnel.requestConfigChange)
    }

    @Test("apply settings suppresses and clears connecting overlay state")
    func applySettingsSuppressesAndClearsConnectingOverlayState() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.connectionCommandReceived(.connect(.defaultFastest, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: .defaultFastest)
        }
        await store.send(.connectionCommandReceived(.applySettings([.agent(.vpnAccelerator(true))]))) {
            $0.overlayState = .suppressed
        }
    }

    @Test("disconnect clears connecting overlay child state")
    func disconnectClearsConnectingOverlayChildState() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.connectionCommandReceived(.connect(.defaultFastest, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: .defaultFastest)
        }
        await store.send(.connectionCommandReceived(.disconnect(.auto))) {
            $0.overlayState = .hidden
        }
    }

    @Test("in-place settings suppress connecting overlay, reconnect commands still show it")
    func inPlaceSettingsSuppressOverlayUntilReconnectCommand() async {
        let store = makeStore()
        store.exhaustivity = .off
        let settings: Set<ConnectionFeatureChange> = [.agent(.portForwarding(true))]

        await store.send(.connectionCommandReceived(.applySettings(settings))) {
            $0.overlayState = .suppressed
        }

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest)))
        #expect(store.state.overlayState == .suppressed)

        await store.send(.connectionCommandReceived(.retry)) {
            $0.overlayState = .connecting(spec: .defaultFastest)
        }
    }

    @Test("refresh finished does not re-enable overlay for in-place updates")
    func refreshFinishedDoesNotReEnableOverlayForInPlaceUpdates() async {
        let store = makeStore()
        store.exhaustivity = .off
        let settings: Set<ConnectionFeatureChange> = [.agent(.portForwarding(true))]

        await store.send(.connectionCommandReceived(.applySettings(settings))) {
            $0.overlayState = .suppressed
        }
        await store.receive(\.connection.input.applySettings)

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest)))
        #expect(store.state.overlayState == .suppressed)
    }

    @Test("successful in-place settings update lifts overlay suppression")
    func successfulInPlaceSettingsUpdateLiftsOverlaySuppression() async {
        let store = makeStore()
        store.exhaustivity = .off
        let connectedState = VPNConnectionActual.mock()

        await store.send(.connectionCommandReceived(.applySettings([.agent(.portForwarding(true))]))) {
            $0.overlayState = .suppressed
        }

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest)))
        #expect(store.state.overlayState == .suppressed)

        // .connected after suppress clears the suppression — no auto-dismiss overlay
        // is shown for the in-place update, but the state goes back to .hidden.
        await store.send(.connectionStateChanged(.testConnected(.defaultFastest, connectedState))) {
            $0.overlayState = .hidden
        }

        // A subsequent passive reconnect is now visible.
        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest))) {
            $0.overlayState = .connecting(synced: .testConnecting(.defaultFastest))
        }
    }

    @Test("clear connection data command forwards to connection logout")
    func clearConnectionDataCommandForwardsToConnectionLogout() async {
        let store = makeStore()

        await store.send(.connectionCommandReceived(.clearConnectionData()))
        await store.receive(\.connection.input.onLogout)
        await store.receive(\.connection.stopObserving)
        await store.receive(\.connection.tunnel.cleanup)
        await store.receive(\.connection.tunnel.stopObserving)
    }

    @Test("command client broadcasts sent commands")
    func commandClientBroadcastsSentCommands() async {
        let client = ConnectionCommandClient.liveValue
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
        #expect(defaults.integer(forKey: "MapWidth") == 575)
    }

    @Test("vpn status updates overlay flag")
    func vpnStatusUpdatesOverlayFlag() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)
        let connectedState = VPNConnectionActual.mock()
        #expect(store.state.connectionState == .resolving)

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest))) {
            $0.overlayState = .connecting(synced: .testConnecting(.defaultFastest))
        }
        await store.send(.connectionStateChanged(.testConnected(.defaultFastest, connectedState))) {
            $0.overlayState = .autoDismiss(for: .testConnected(.defaultFastest, connectedState))
        }
        await clock.advance(by: .seconds(3))
        await store.receive(\.connectedOverlayDelayElapsed) {
            $0.overlayState = .hidden
        }
    }

    @Test("overlay dismissal by user hides overlay and allows next connection overlay")
    func overlayDismissedByUserHidesOverlayAndAllowsNextConnectionOverlay() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)
        let connectedState = VPNConnectionActual.mock()
        #expect(store.state.connectionState == .resolving)

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest))) {
            $0.overlayState = .connecting(synced: .testConnecting(.defaultFastest))
        }
        await store.send(.connectionStateChanged(.testConnected(.defaultFastest, connectedState))) {
            $0.overlayState = .autoDismiss(for: .testConnected(.defaultFastest, connectedState))
        }

        await store.send(.overlayDismissedByUser) {
            $0.overlayState = .hidden
        }

        await clock.advance(by: .seconds(3))

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest))) {
            $0.overlayState = .connecting(synced: .testConnecting(.defaultFastest))
        }
    }

    @Test("connect command immediately shows overlay even without status transition")
    func connectCommandImmediatelyShowsOverlayEvenWithoutStatusTransition() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.overlayDismissedByUser)
        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .quick))) {
            $0.overlayState = .connecting(spec: spec)
        }
    }

    @Test("connect command clears frozen connected overlay snapshot")
    func connectCommandClearsFrozenConnectedOverlaySnapshot() async {
        let spec = ConnectionSpec(location: .any(.fastest), features: [])
        let connectedState = VPNConnectionActual.mock()
        let clock = TestClock()
        let store = makeStore(clock: clock)
        store.exhaustivity = .off

        // Populate the autoDismiss snapshot via the normal app-initiated flow
        // (.connecting → .connected). A direct .connected with no preceding .connecting
        // would now be treated as an OS-initiated tunnel and skip the overlay entirely.
        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest))) {
            $0.overlayState = .connecting(synced: .testConnecting(.defaultFastest))
        }
        await store.send(.connectionStateChanged(.testConnected(.defaultFastest, connectedState))) {
            $0.overlayState = .autoDismiss(for: .testConnected(.defaultFastest, connectedState))
        }

        await store.send(.connectionCommandReceived(.connect(spec, .vpnProtocol(.ike), .changeServer))) {
            $0.overlayState = .connecting(spec: spec)
        }
    }

    @Test("OS-initiated .connected without preceding .connecting skips the overlay")
    func osInitiatedConnectedSkipsOverlay() async {
        let connectedState = VPNConnectionActual.mock()
        let store = makeStore()
        #expect(store.state.overlayState == .hidden)

        await store.send(.connectionStateChanged(.testConnected(.defaultFastest, connectedState)))
        #expect(store.state.overlayState == .hidden)
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

        #expect(!store.state.shouldPresentLoadingOverlay)
    }

    @Test("change server optional action reconnect shows connecting overlay")
    func changeServerOptionalActionReconnectShowsConnectingOverlay() async {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let until = now.addingTimeInterval(60)
        let duration: TimeInterval = 600
        let spec = ConnectionSpec(location: .any(.random), features: [])
        let store = makeStore(
            serverChangeAuthorizer: .init(
                serverChangeAvailability: {
                    if now < until {
                        .unavailable(until: until, duration: duration, exhaustedSkips: true)
                    } else {
                        .available
                    }
                },
                registerServerChangeAtDate: { _ in }
            )
        )
        store.exhaustivity = .off // the connection layer runs for real here; see the note on the suite

        // First attempt: blocked, so cantSkip upsell is presented.
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
        #expect(!store.state.shouldPresentLoadingOverlay)

        // Simulate timer elapsed before user taps "Change server".
        now = until.addingTimeInterval(1)

        await store.send(.countriesSection(.quickSettings(.destination(.presented(.upsell(.skipActionTapped)))))) {
            $0.countriesSection.quickSettings.destination = nil
            $0.pendingReconnectIntent = nil
            $0.overlayState = .connecting(spec: spec)
        }
        await store.receive(\.connection.input.connect, ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: .vpnProtocol(.ike),
            acceptableProtocols: .ikev2
        ))
        await store.receive(\.connection.delegate.stateChanged.connecting)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
        #expect(store.state.shouldPresentLoadingOverlay)
    }

    @Test("fullscreen flags")
    func fullscreenFlags() async {
        let store = makeStore()

        await store.send(.windowWillEnterFullScreen) {
            $0.isFullscreen = true
        }
        await store.send(.windowWillExitFullScreen) {
            $0.isFullscreen = false
        }
    }

    @Test("overlay presentation follows overlay state")
    func overlayPresentationFollowsOverlayState() async {
        let store = makeStore()
        #expect(store.state.connectionState == .resolving)
        #expect(!store.state.shouldPresentLoadingOverlay)

        await store.send(.connectionStateChanged(.testConnecting(.defaultFastest))) {
            $0.overlayState = .connecting(synced: .testConnecting(.defaultFastest))
        }
        #expect(store.state.shouldPresentLoadingOverlay)

        await store.send(.connectionStateChanged(.disconnected)) {
            $0.overlayState = .hidden
        }
        #expect(!store.state.shouldPresentLoadingOverlay)
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
        defaults.set(720, forKey: "MapWidth")
        // `startObservingEvents` starts the maintenance feature, which schedules its refresh on the continuous clock.
        let store = makeStore(defaults: defaults, clock: TestClock())
        store.exhaustivity = .off

        await store.send(.viewDidLoad) {
            $0.mapWidth = 720
        }
        await store.receive(\.connection.input.onLaunch)
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
        await store.receive(\.startObservingEvents)

        await store.send(.stopObservingEvents)
    }

    @Test("connection delegate state change re-syncs NAT port mapping and plutonium")
    func connectionDelegateStateChangeResyncsNATAndPlutonium() async {
        let store = makeStore()
        #expect(store.state.connectionState == .resolving)

        // The delegate only reports; the connection layer owns `.connectionState` and has already written it. The
        // sidebar's own reaction is to re-evaluate the two services that follow the connection.
        await store.send(.connection(.delegate(.stateChanged(.disconnected))))
        await store.receive(\.syncNATPortMappingState)
        await store.receive(\.syncPlutoniumState)
    }

    @Test("2FA local agent notice shows an actionable alert")
    func twoFactorLocalAgentNoticeShowsAlert() async {
        let receivedAlert = OSAllocatedUnfairLock<WarningAlert?>(initialState: nil)
        let store = makeStore(coreAlertService: .init(push: { alert in
            guard let alert = alert as? WarningAlert else { return }
            receivedAlert.withLock { $0 = alert }
        }))

        await store.send(.connection(.delegate(.localAgentNotice(.authenticationRequired))))

        let alert = receivedAlert.withLock { $0 }
        #expect(alert?.actions.map(\.title) == ["Open 2FA", Localizable.disconnect])
        #expect(alert?.actions.allSatisfy { $0.handler != nil } == true)
    }

    // MARK: - Port forwarding

    @Test("a failed port mapping is reported to the user and clears the port")
    func failedPortMappingIsReported() async {
        await confirmation("port forwarding error shown") { shown in
            let store = makeStore(
                clock: TestClock(),
                portForwardingNotifications: true,
                notificationManager: .init(
                    displayServerGoingOnMaintenance: {},
                    displayPFChange: { _ in Issue.record("No port was mapped") },
                    displayPFError: { shown() }
                )
            )
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.startObservingEvents)
            @Dependency(\.natPortMappingService) var service
            service.portMappingStream.send(.failure(NATPortMappingError.mappingFailed))

            await store.receive(\.portMappingChanged)
            #expect(store.state.header.mappedPort == nil)
            await store.send(.stopObservingEvents)
        }
    }

    @Test("nothing is reported while port forwarding notifications are off")
    func nothingReportedWhileNotificationsOff() async {
        let store = makeStore(
            clock: TestClock(),
            portForwardingNotifications: false,
            notificationManager: .init(
                displayServerGoingOnMaintenance: {},
                displayPFChange: { _ in Issue.record("The user asked not to hear about this") },
                displayPFError: { Issue.record("The user asked not to hear about this") }
            )
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.startObservingEvents)
        @Dependency(\.natPortMappingService) var service
        service.portMappingStream.send(.failure(NATPortMappingError.mappingFailed))

        await store.receive(\.portMappingChanged)
        await store.send(.stopObservingEvents)
    }

    @Test("port mapping addresses the tunnel gateway, not the user's custom DNS resolver")
    func portMappingAddressesTunnelGateway() async {
        let service = NATPortMappingServiceMock()
        let store = withDependencies {
            $0.hermesClient = .customDNS(resolvers: [.cloudFlare])
            $0.natPortMappingService = service
        } operation: {
            makeStore(
                connectionState: .previewConnected(for: ConnectionSpec(location: .any(.fastest), features: [.p2p])),
                featureFlags: .enabling(VPNFeatureFlagType.portForwarding),
                portForwardingEnabled: true
            )
        }

        await store.send(.syncNATPortMappingState) {
            $0.natPortMappingRunning = true
        }
        await store.finish()

        #expect(service.requestedGatewayAddresses == [VpnProtocol.wireGuardGatewayAddress])
    }

    // MARK: - Private

    private func makeStore(
        environment: SidebarFeature.Environment = .init(
            sidebarWidth: 425,
            expandButtonWidth: 28,
            defaultMapWidth: 600
        ),
        connectionState: ConnectionState = .resolving,
        defaults: UserDefaults = .inMemory,
        clock: TestClock<Duration>? = nil,
        coreAlertService: CoreAlertService = .testValue,
        // `SidebarFeature.State` (via the quick settings) and the NAT-PMP sync read
        // `VPNFeatureFlagType.portForwarding`. Every flag stays off by default, matching the flagless
        // environment most of these expectations were written against.
        featureFlags: FeatureFlagsClient = .enabling(),
        portForwardingEnabled: Bool = false,
        portForwardingNotifications: Bool = false,
        notificationManager: NotificationManager = .init(
            displayServerGoingOnMaintenance: {},
            displayPFChange: { _ in },
            displayPFError: {}
        ),
        serverChangeAuthorizer: ServerChangeAuthorizer = .availableValue
    ) -> TestStoreOf<SidebarFeature> {
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            // Both handles have to be created in this dependency scope: `.connectionState` is keyed by the
            // `UserDefaults` it lives in, so a handle made outside `withDependencies` addresses other storage than
            // the store does.
            @Shared(.connectionState) var sharedConnectionState
            @Shared(.connectionProtocol) var sharedConnectionProtocol

            $sharedConnectionState.withLock { $0 = connectionState }
            $sharedConnectionProtocol.withLock { $0 = .vpnProtocol(.ike) }

            // Port forwarding notifications are a paid setting stored per user, so the reducer's check
            // needs a tier that may use it and a username to resolve the storage key with.
            let keychain = MockAuthKeychain()
            keychain.username = "test-user"
            withDependencies {
                $0.defaultAppStorage = defaults
                $0.authKeychain = keychain
            } operation: {
                @Shared(.userTier) var userTier
                $userTier.withLock { $0 = .paid }
                AuthorizedFeatureValue<PortForwardingNotifications>()
                    .setValue(portForwardingNotifications ? .on : .off)
            }

            let session = VPNSessionMock(status: .disconnected)
            session.messageHandler = MessageHandler.full

            return TestStore(initialState: SidebarFeature.State()) {
                SidebarFeature(
                    environment: environment
                )
            } withDependencies: {
                $0.featureFlags = featureFlags
                if let clock {
                    $0.continuousClock = clock
                }
                $0.connectionFeatureProvider = .init(
                    connectionFeatures: {
                        .init(netshield: .off, vpnAccelerator: false, natType: .strictNAT, portForwarding: false)
                    },
                    requestedFeatures: { .init(killSwitchMode: .off, excludeLocalNetworks: false) },
                    connectionProtocol: { .smartProtocol }
                )
                $0.tunnelManager = MockTunnelManager(connection: session)
                $0.connectionCommandClient = .testValue
                $0.coreAlertService = coreAlertService
                // A fresh queue per store, so a completion left behind by one test cannot run in the next.
                $0.pendingDisconnectCompletions = PendingDisconnectCompletions()
                $0.portForwardingPropertyProvider.setPortForwarding(portForwardingEnabled)
                $0.serverChangeAuthorizer = serverChangeAuthorizer
                $0.authKeychain = keychain
                $0.notificationManager = notificationManager
                $0.announcementRefresher.tryRefreshing = {}
                $0.withRandomNumberGenerator = WithRandomNumberGenerator(SystemRandomNumberGenerator())
            }
        }
    }
}

private extension HermesClient {
    /// Custom DNS turned on, with `resolvers` as the servers the tunnel hands to the host. Port
    /// forwarding still has to address the tunnel gateway in this setup, whatever those servers are.
    static func customDNS(resolvers: [HermesResolver]) -> Self {
        var client = Self.testValue
        client.isEnabled = { SharedReader(value: true) }
        client.activeHermesResolvers = { SharedReader(value: resolvers) }
        return client
    }
}

private extension SidebarFeature.State.OverlayState {
    /// Overlay state after `beginConnectingOverlay` (no `sync` follow-up).
    static func connecting(
        spec _: ConnectionSpec,
        selectedProtocol: ConnectionProtocol = .vpnProtocol(.ike),
        killSwitchEnabled: Bool = false,
        frozenState: ConnectionState? = nil
    ) -> Self {
        var overlay = ConnectingOverlayFeature.State()
        overlay.connectionState = .resolving
        overlay.selectedProtocol = selectedProtocol
        overlay.killSwitchEnabled = killSwitchEnabled
        overlay.frozenState = frozenState
        return .connecting(overlay)
    }

    /// Overlay state after `beginConnectingOverlay` + `syncConnectingOverlayState(state:)`.
    static func connecting(
        synced state: ConnectionState,
        selectedProtocol: ConnectionProtocol = .vpnProtocol(.ike),
        killSwitchEnabled: Bool = false
    ) -> Self {
        var overlay = ConnectingOverlayFeature.State()
        overlay.connectionState = state
        overlay.frozenState = state.is(\.connected) ? state : nil
        overlay.selectedProtocol = selectedProtocol
        overlay.killSwitchEnabled = killSwitchEnabled
        return .connecting(overlay)
    }

    static func autoDismiss(
        for state: ConnectionState,
        selectedProtocol: ConnectionProtocol = .vpnProtocol(.ike),
        killSwitchEnabled: Bool = false
    ) -> Self {
        var overlay = ConnectingOverlayFeature.State()
        overlay.connectionState = state
        overlay.frozenState = state.is(\.connected) ? state : nil
        overlay.selectedProtocol = selectedProtocol
        overlay.killSwitchEnabled = killSwitchEnabled
        return .autoDismiss(overlay)
    }
}

private extension ConnectionState {
    /// Build a `.connecting(.unresolved)` state from a spec
    static func testConnecting(_ spec: ConnectionSpec) -> ConnectionState {
        .connecting(
            .unresolved(ConnectionPreparationIntent(spec: spec, acceptableProtocols: .ikev2)),
            tunnelActive: false
        )
    }

    /// Build a `.connected` state from a spec and a `VPNConnectionActual`. The caller passes the actual in so that
    /// the state it sends and the state it asserts against carry the same connection date: `VPNConnectionActual.mock()`
    /// stamps `Date()` on every call, so building one here would make the two dates differ by a few milliseconds.
    static func testConnected(_ spec: ConnectionSpec, _ actual: VPNConnectionActual) -> ConnectionState {
        .connected(
            .init(connectionSpec: spec, tunnelProtocol: .ike, peerIDs: ["peer-id"], killSwitch: false),
            .init(currentPeer: actual.server, connectionDate: actual.connectedDate ?? .now, protocolConnectionData: .ike)
        )
    }
}
