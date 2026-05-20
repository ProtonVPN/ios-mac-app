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

import Combine
import ComposableArchitecture
import Connection
import CoreGraphics
import Domain
import ExtensionManager
import Foundation
import LegacyCommon
import PaymentsShared
import Persistence
import ProtonCoreFeatureFlags
import VPNAppCore

@Reducer
struct SidebarFeature {
    @ObservableState
    struct State: Equatable {
        enum OverlayPresentationPolicy: Equatable {
            case automatic
            case suppressForInPlaceSettingsUpdate
        }

        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @Shared(.connectionState) var connectionState: ConnectionState
        var connection: ConnectionFeature.State = .initialState

        enum ExpandState: Equatable {
            case compact
            case expanded
        }

        var selectedTab: SidebarTab = .countries
        var isLoadingOverlayVisible = false
        var overlayPresentationPolicy: OverlayPresentationPolicy = .automatic
        var isOverlayWindowPresented = false
        var expandState: ExpandState = .compact
        var mapWidth: CGFloat = 600
        var isFullscreen = false
        var isOccludedVisible = true
        var natPortMappingRunning = false
        var connectingOverlay = ConnectingOverlayFeature.State()
        var countriesSection = CountriesSectionFeature.State()
        @Presents var alert: AlertState<Action.Alert>?
        var pendingReconnectIntent: ConnectionPreparationIntent?

        var isExpandButtonHidden: Bool {
            isFullscreen
        }

        var shouldPresentLoadingOverlay: Bool {
            isLoadingOverlayVisible && isOccludedVisible
        }
    }

    enum Action {
        case connection(ConnectionFeature.Action)

        case viewDidLoad
        case viewDidAppear
        case mouseDown
        case startObservingEvents
        case stopObservingEvents
        case connectedOverlayDelayElapsed
        case overlayWindowPresentedChanged(Bool)
        case overlayDismissedByUser

        case windowDidResize(width: CGFloat, height: CGFloat)
        case windowDidEndLiveResize(width: CGFloat, isFullscreen: Bool)
        case windowWillEnterFullScreen
        case windowWillExitFullScreen
        case occlusionStateChanged(isVisible: Bool)
        case killSwitchSettingChanged(Bool)
        case vpnConnectionStatusUpdated(VPNConnectionStatus)
        case syncNATPortMappingState
        case syncPlutoniumState
        case connectingOverlay(ConnectingOverlayFeature.Action)

        case tabChanged(SidebarTab)
        case expandButtonTapped
        case connectionCommandReceived(SidebarConnectionCommand)

        case countriesSection(CountriesSectionFeature.Action)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {}
    }

    // MARK: - Init

    init(
        environment: Environment
    ) {
        self.environment = environment
    }

    struct Environment {
        var sidebarWidth: CGFloat
        var expandButtonWidth: CGFloat
        var defaultMapWidth: CGFloat
    }

    private let environment: Environment
    @Dependency(\.defaultsProvider) private var defaultsProvider
    @Dependency(\.sidebarEventsClient) private var sidebarEventsClient
    @Dependency(\.sidebarConnectionCommandClient) private var sidebarConnectionCommandClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.natPortMappingService) private var natPortMappingService
    @Dependency(\.plutoniumManager) private var plutoniumManager
    @Dependency(\.hermesClient) private var hermesClient
    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer

    var body: some ReducerOf<Self> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()
                ._printChanges()
        }

        Scope(state: \.countriesSection, action: \.countriesSection) {
            CountriesSectionFeature()
        }
        Scope(state: \.connectingOverlay, action: \.connectingOverlay) {
            ConnectingOverlayFeature()
        }

        Reduce { state, action in
            switch action {
            case .viewDidLoad:
                state.selectedTab = .countries
                syncConnectingOverlayState(&state, connectionStatus: state.vpnConnectionStatus)
                let loadedMapWidth = defaultsProvider.getDefaults().integer(forKey: AppConstants.UserDefaults.mapWidth)
                state.mapWidth = loadedMapWidth > Int(environment.expandButtonWidth) ? CGFloat(loadedMapWidth) : environment.defaultMapWidth
                return .merge(
                    .send(.connection(.input(.onLaunch))),
                    .send(.syncNATPortMappingState),
                    .send(.syncPlutoniumState),
                    .send(.startObservingEvents)
                )

            case .startObservingEvents:
                return .merge(
                    .run { send in
                        for await resize in sidebarEventsClient.windowDidResize() {
                            await send(.windowDidResize(width: resize.width, height: resize.height))
                        }
                    }
                    .cancellable(id: CancelID.windowResize),
                    .run { send in
                        for await event in sidebarEventsClient.windowDidEndLiveResize() {
                            await send(.windowDidEndLiveResize(width: event.width, isFullscreen: event.isFullscreen))
                        }
                    }
                    .cancellable(id: CancelID.windowEndResize),
                    .run { send in
                        for await _ in sidebarEventsClient.windowWillEnterFullScreen() {
                            await send(.windowWillEnterFullScreen)
                        }
                    }
                    .cancellable(id: CancelID.windowEnterFullScreen),
                    .run { send in
                        for await _ in sidebarEventsClient.windowWillExitFullScreen() {
                            await send(.windowWillExitFullScreen)
                        }
                    }
                    .cancellable(id: CancelID.windowExitFullScreen),
                    .run { send in
                        for await isVisible in sidebarEventsClient.occlusionStateChanged() {
                            await send(.occlusionStateChanged(isVisible: isVisible))
                        }
                    }
                    .cancellable(id: CancelID.occlusion),
                    .run { send in
                        let stream = await sidebarConnectionCommandClient.stream()
                        for await command in stream {
                            await send(.connectionCommandReceived(command))
                        }
                    }
                    .cancellable(id: CancelID.connectionCommands),
                    .run { send in
                        for await _ in portForwardingPropertyProvider.portForwardingStream() {
                            await send(.syncNATPortMappingState)
                        }
                    }
                    .cancellable(id: CancelID.portForwardingSetting),
                    .run { send in
                        @SharedReader(.plutoniumFeature) var plutoniumFeature
                        for await _ in $plutoniumFeature.publisher.values {
                            await send(.syncPlutoniumState)
                        }
                    }
                    .cancellable(id: CancelID.plutoniumSetting),
                    .run { send in
                        @SharedReader(.killSwitch) var killSwitch
                        for await value in $killSwitch.publisher.removeDuplicates().values.dropFirst() {
                            await send(.killSwitchSettingChanged(value))
                        }
                    }
                    .cancellable(id: CancelID.killSwitchSetting)
                )

            case .stopObservingEvents:
                return .merge(
                    .cancel(id: CancelID.windowResize),
                    .cancel(id: CancelID.windowEndResize),
                    .cancel(id: CancelID.windowEnterFullScreen),
                    .cancel(id: CancelID.windowExitFullScreen),
                    .cancel(id: CancelID.occlusion),
                    .cancel(id: CancelID.overlayDelay),
                    .cancel(id: CancelID.connectionCommands),
                    .cancel(id: CancelID.portForwardingSetting),
                    .cancel(id: CancelID.plutoniumSetting),
                    .cancel(id: CancelID.killSwitchSetting),
                    .cancel(id: CancelID.connectionConnectCommandEffect),
                    .cancel(id: CancelID.connectionDisconnectCommandEffect),
                    .cancel(id: CancelID.plutoniumSync)
                )

            case .viewDidAppear, .mouseDown:
                return .none

            case let .windowDidResize(width, _):
                state.expandState = width <= environment.sidebarWidth + environment.expandButtonWidth ? .compact : .expanded
                return .none

            case let .windowDidEndLiveResize(width, isFullscreen):
                state.expandState = width <= environment.sidebarWidth + environment.expandButtonWidth ? .compact : .expanded
                guard !isFullscreen, state.expandState == .expanded, width > environment.sidebarWidth + environment.expandButtonWidth else {
                    return .none
                }
                let mapWidth = Int(width - environment.sidebarWidth)
                state.mapWidth = CGFloat(mapWidth)
                defaultsProvider.getDefaults().set(mapWidth, forKey: AppConstants.UserDefaults.mapWidth)
                return .none

            case .windowWillEnterFullScreen:
                state.isFullscreen = true
                return .none

            case .windowWillExitFullScreen:
                state.isFullscreen = false
                return .none

            case let .occlusionStateChanged(isVisible):
                state.isOccludedVisible = isVisible
                return .none

            case .killSwitchSettingChanged:
                guard state.vpnConnectionStatus.isConnected(using: state.connectionState) else {
                    return .none
                }
                state.overlayPresentationPolicy = .automatic
                state.isLoadingOverlayVisible = true
                let spec = propertiesManager.lastConnectionIntent
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: propertiesManager.connectionProtocol
                )
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .send(.connection(.input(.connect(intent))))
                )

            case let .vpnConnectionStatusUpdated(connectionStatus):
                state.$vpnConnectionStatus.withLock { $0 = connectionStatus }
                syncConnectingOverlayState(&state, connectionStatus: connectionStatus)
                switch connectionStatus {
                case .resolving, .connecting:
                    if state.overlayPresentationPolicy == .automatic {
                        state.isLoadingOverlayVisible = true
                    }
                    return .cancel(id: CancelID.overlayDelay)

                case .connected:
                    state.overlayPresentationPolicy = .automatic
                    return .run { send in
                        try await clock.sleep(for: .seconds(3))
                        await send(.connectedOverlayDelayElapsed)
                    }
                    .cancellable(id: CancelID.overlayDelay, cancelInFlight: true)

                case .disconnecting, .disconnected:
                    state.overlayPresentationPolicy = .automatic
                    state.isLoadingOverlayVisible = false
                    return .cancel(id: CancelID.overlayDelay)
                }

            case .syncNATPortMappingState:
                let shouldRunNatPortMapping = VPNFeatureFlagType.portForwarding.enabled
                    && portForwardingPropertyProvider.getPortForwarding() == true
                    && connectionStateSupportsNatPortMapping(state.connectionState)

                guard shouldRunNatPortMapping != state.natPortMappingRunning else {
                    return .none
                }
                state.natPortMappingRunning = shouldRunNatPortMapping

                if shouldRunNatPortMapping {
                    guard let gatewayAddress = natPortMappingGatewayAddress(from: state.connectionState) else {
                        state.natPortMappingRunning = false
                        log.error("Cannot start NAT port mapping - unable to determine gateway address", category: .connection)
                        return .none
                    }
                    return .run { _ in
                        natPortMappingService.startPortMapping(gatewayAddress: gatewayAddress)
                        log.info("NAT port mapping service started", category: .connection)
                    }
                } else {
                    return .run { _ in
                        await natPortMappingService.cancelPortMapping()
                        log.info("NAT port mapping service stopped", category: .connection)
                    }
                }

            case .syncPlutoniumState:
                let connectionState = state.connectionState
                return .run { _ in
                    @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
                    guard FeatureFlagsRepository.shared
                        .isEnabled(VPNFeatureFlagType.plutoniumMacOS, reloadValue: true), case .enabled = feature
                    else {
                        try await plutoniumManager.stop()
                        return
                    }

                    if connectionState.is(\.connected) {
                        try await plutoniumManager.start()
                    } else {
                        try await plutoniumManager.stop()
                    }
                } catch: { error, _ in
                    if case let PlutoniumManagerError.saveFailed(saveError) = error {
                        log.error("Error while saving plutonium manager: \(saveError)")
                    } else {
                        log.error("Error while updating plutonium state: \(error.localizedDescription)")
                    }
                }
                .cancellable(id: CancelID.plutoniumSync, cancelInFlight: true)

            case .connectedOverlayDelayElapsed:
                state.isLoadingOverlayVisible = false
                return .none

            case let .overlayWindowPresentedChanged(isPresented):
                state.isOverlayWindowPresented = isPresented
                return .none

            case .overlayDismissedByUser:
                state.isLoadingOverlayVisible = false
                return .cancel(id: CancelID.overlayDelay)

            case .connectingOverlay(.delegate(.dismissRequested)):
                return .send(.overlayDismissedByUser)

            case let .tabChanged(tab):
                state.selectedTab = tab
                return .none

            case .expandButtonTapped:
                state.expandState = state.expandState == .compact ? .expanded : .compact
                return .none

            case let .connectionCommandReceived(.connect(spec, connectionProtocol, trigger)):
                if trigger == .changeServer {
                    let availability = serverChangeAuthorizer.serverChangeAvailability()
                    if case let .unavailable(until, duration, exhaustedSkips) = availability {
                        let intent = connectionPreparationIntent(
                            spec: spec,
                            connectionProtocol: connectionProtocol ?? propertiesManager.connectionProtocol
                        )
                        state.pendingReconnectIntent = intent
                        return .send(.countriesSection(.quickSettings(.presentUpsell(
                            .cantSkip(
                                before: until,
                                totalDuration: duration,
                                longSkip: exhaustedSkips
                            )
                        ))))
                    }
                }

                state.overlayPresentationPolicy = .automatic
                state.isLoadingOverlayVisible = true
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol ?? propertiesManager.connectionProtocol
                )
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .run { send in
                        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))
                        await send(.connection(.input(.connect(intent))))
                    }
                    .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
                )

            case let .connectionCommandReceived(.disconnect(trigger, completion)):
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(trigger)
                    await send(.connection(.input(.disconnect)))
                    await completion?()
                }
                .cancellable(id: CancelID.connectionDisconnectCommandEffect, cancelInFlight: true)

            case .connectionCommandReceived(.retry):
                state.overlayPresentationPolicy = .automatic
                state.isLoadingOverlayVisible = true
                let spec = propertiesManager.lastConnectionIntent
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: propertiesManager.connectionProtocol
                )
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .run { send in
                        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                        await send(.connection(.input(.connect(intent))))
                    }
                    .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
                )

            case let .connectionCommandReceived(.reconnect(connectionProtocol)):
                state.overlayPresentationPolicy = .automatic
                state.isLoadingOverlayVisible = true
                let spec = propertiesManager.lastConnectionIntent
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol ?? propertiesManager.connectionProtocol
                )
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .run { send in
                        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                        await send(.connection(.input(.connect(intent))))
                    }
                    .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
                )

            case let .connectionCommandReceived(.applySettings(settings)):
                state.overlayPresentationPolicy = .suppressForInPlaceSettingsUpdate
                return .send(.connection(.input(.applySettings(settings))))

            case let .connectionCommandReceived(.clearConnectionData(completion)):
                return .run { send in
                    await send(.connection(.input(.onLogout)))
                    await completion?()
                }

            case .countriesSection(.delegate(.openProfilesTab)):
                state.selectedTab = .profiles
                return .none

            case .countriesSection(.quickSettings(.destination(.presented(.upsell(.optionalActionTapped))))):
                guard let intent = state.pendingReconnectIntent else {
                    return .none
                }
                state.pendingReconnectIntent = nil
                state.overlayPresentationPolicy = .automatic
                state.isLoadingOverlayVisible = true
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .send(.connection(.input(.connect(intent))))
                )

            case .countriesSection(.quickSettings(.destination(.presented(.upsell(.continueTapped))))),
                 .countriesSection(.quickSettings(.destination(.presented(.upsell(.upgradeTapped))))),
                 .countriesSection(.quickSettings(.destination(.dismiss))):
                state.pendingReconnectIntent = nil
                return .none

            case .countriesSection, .connectingOverlay:
                return .none

            case .alert:
                return .none

            case let .connection(.delegate(.connectionFailed(error))):
                SentryHelper.shared?.log(error: error)
                state.alert = connectionFailureAlert(for: error)
                return .none

            case let .connection(.delegate(.stateChanged(connectionState))):
                log.debug("Connection layer state update \(connectionState)")
                state.$connectionState.withLock { $0 = connectionState }
                let fallbackSpec = state.vpnConnectionStatus.spec ?? propertiesManager.lastConnectionIntent
                return .merge(
                    .send(.vpnConnectionStatusUpdated(connectionState.vpnConnectionStatus(
                        fallbackSpec: fallbackSpec,
                        previousStatus: state.vpnConnectionStatus
                    ))),
                    .send(.syncNATPortMappingState),
                    .send(.syncPlutoniumState)
                )

            case let .connection(.delegate(.intentResolutionFailed(intent, resolutionError))):
                SentryHelper.shared?.log(error: resolutionError)
                switch resolutionError {
                case .secureCoreUnavailable:
                    state.pendingReconnectIntent = nil
                    return .send(.countriesSection(.quickSettings(.presentUpsell(.secureCore))))
                case let .specificCountryUnavailable(countryCode):
                    state.pendingReconnectIntent = nil
                    return .send(.countriesSection(.quickSettings(.presentUpsell(
                        .country(
                            countryCode: countryCode,
                            numberOfDevices: DomainConstants.maxDeviceCount,
                            numberOfCountries: serverRepository.countryCount()
                        )
                    ))))
                case .serverChangeUnavailable:
                    let availability = serverChangeAuthorizer.serverChangeAvailability()
                    guard case let .unavailable(until, duration, exhaustedSkips) = availability else {
                        state.pendingReconnectIntent = nil
                        return .none
                    }
                    state.pendingReconnectIntent = intent
                    return .send(.countriesSection(.quickSettings(.presentUpsell(
                        .cantSkip(
                            before: until,
                            totalDuration: duration,
                            longSkip: exhaustedSkips
                        )
                    ))))
                }

            case .connection(.core(.certAuth(.refreshFinished))):
                return .none

            case .connection:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private enum CancelID {
        case windowResize
        case windowEndResize
        case windowEnterFullScreen
        case windowExitFullScreen
        case occlusion
        case overlayDelay
        case connectionCommands
        case portForwardingSetting
        case plutoniumSetting
        case killSwitchSetting
        case connectionConnectCommandEffect
        case connectionDisconnectCommandEffect
        case plutoniumSync
    }
}

private extension SidebarFeature {
    func syncConnectingOverlayState(_ state: inout State, connectionStatus: VPNConnectionStatus) {
        state.connectingOverlay.vpnConnectionStatus = connectionStatus
        state.connectingOverlay.selectedProtocol = propertiesManager.connectionProtocol
        state.connectingOverlay.killSwitchEnabled = propertiesManager.killSwitch
        state.connectingOverlay.intentionallyDisconnected = propertiesManager.intentionallyDisconnected
        if connectionStatus.is(\.connected) {
            state.connectingOverlay.frozenStatus = connectionStatus
        } else {
            state.connectingOverlay.frozenStatus = nil
        }
    }

    func connectionFailureAlert(for error: ConnectionError) -> AlertState<Action.Alert> {
        let alert = error.alert
        return AlertState {
            TextState(String(localized: alert.title))
        } message: {
            TextState(String(localized: alert.message))
        }
    }

    func connectionPreparationIntent(
        spec: ConnectionSpec,
        connectionProtocol: ConnectionProtocol
    ) -> ConnectionPreparationIntent {
        let spec = enforceP2PIfPortForwardingEnabled(spec)
        let acceptableProtocols: ProtocolSupport = switch connectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            vpnProtocol.protocolSupport
        case .smartProtocol:
            propertiesManager.smartProtocolConfig.supportedProtocols
                .reduce(.zero) { $0.union($1.protocolSupport) }
        }
        return ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: connectionProtocol,
            acceptableProtocols: acceptableProtocols
        )
    }

    func enforceP2PIfPortForwardingEnabled(_ spec: ConnectionSpec) -> ConnectionSpec {
        guard portForwardingPropertyProvider.getPortForwarding() == true else {
            return spec
        }
        switch spec.location {
        case .any, .country, .city, .state:
            if spec.features.contains(.p2p) {
                return spec
            }
            var features = spec.features
            features.insert(.p2p)
            return ConnectionSpec(location: spec.location, features: features, profileId: spec.profileId)
        case .exact, .secureCore, .gateway:
            return spec
        }
    }

    func connectionStateSupportsNatPortMapping(_ connectionState: ConnectionState) -> Bool {
        connectionState.is(\.connected)
    }

    func natPortMappingGatewayAddress(from connectionState: ConnectionState) -> String? {
        let activeVpnProtocol = connectionState.resolvedVpnProtocol ?? currentlySelectedVpnProtocol()
        guard let activeVpnProtocol else {
            return nil
        }
        switch activeVpnProtocol {
        case .ike:
            return "10.1.0.1"
        case .wireGuard:
            return wireGuardGatewayAddress()
        }
    }

    func currentlySelectedVpnProtocol() -> VpnProtocol? {
        switch propertiesManager.connectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            vpnProtocol
        case .smartProtocol:
            nil
        }
    }

    func wireGuardGatewayAddress() -> String {
        let hermesIsEnabled = hermesClient.isEnabled().wrappedValue
        let hermesIsAllowed = featureAuthorizerProvider.authorizer(for: HermesFeature.self)().isAllowed
        if hermesIsEnabled, hermesIsAllowed {
            return "10.2.0.1"
        }
        return propertiesManager.wireguardConfig.dnsServers?.first ?? "10.2.0.1"
    }
}
