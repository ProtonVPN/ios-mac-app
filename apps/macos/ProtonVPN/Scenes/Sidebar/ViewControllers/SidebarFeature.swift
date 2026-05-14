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
import ProtonCoreFeatureFlags
import VPNAppCore

@Reducer
struct SidebarFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @Shared(.connectionState) var connectionState: ConnectionState
        var connection: ConnectionFeature.State = .initialState

        enum ExpandState: Equatable {
            case compact
            case expanded
        }

        var selectedTab: SidebarTab = .countries
        var isLoadingOverlayVisible = false
        var isOverlayWindowPresented = false
        var expandState: ExpandState = .compact
        var mapWidth: CGFloat = 600
        var isFullscreen = false
        var isOccludedVisible = true
        var natPortMappingRunning = false
        var countriesSection = CountriesSectionFeature.State()

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
        case connectedOverlayDelayElapsed
        case overlayWindowPresentedChanged(Bool)
        case overlayDismissedByUser

        case windowDidResize(width: CGFloat, height: CGFloat)
        case windowDidEndLiveResize(width: CGFloat, isFullscreen: Bool)
        case windowWillEnterFullScreen
        case windowWillExitFullScreen
        case occlusionStateChanged(isVisible: Bool)
        case vpnConnectionStatusUpdated(VPNConnectionStatus)
        case syncNATPortMappingState
        case syncPlutoniumState

        case tabChanged(SidebarTab)
        case expandButtonTapped
        case connectionCommandReceived(SidebarConnectionCommand)

        case countriesSection(CountriesSectionFeature.Action)
    }

    // MARK: - Init

    init(
        quickSettingsEnvironment: QuickSettingsFeature.Environment,
        environment: Environment
    ) {
        self.quickSettingsEnvironment = quickSettingsEnvironment
        self.environment = environment
    }

    struct Environment {
        var sidebarWidth: CGFloat
        var expandButtonWidth: CGFloat
        var defaultMapWidth: CGFloat
    }

    private let quickSettingsEnvironment: QuickSettingsFeature.Environment
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
    @Dependency(\.pushAlert) private var pushAlert

    var body: some ReducerOf<Self> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()
                ._printChanges()
        }

        Scope(state: \.countriesSection, action: \.countriesSection) {
            CountriesSectionFeature(quickSettingsEnvironment: quickSettingsEnvironment)
        }

        Reduce { state, action in
            switch action {
            case .viewDidLoad:
                state.selectedTab = .countries
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
                    .cancellable(id: CancelID.plutoniumSetting)
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

            case let .vpnConnectionStatusUpdated(connectionStatus):
                state.$vpnConnectionStatus.withLock { $0 = connectionStatus }
                switch connectionStatus {
                case .resolving, .connecting:
                    state.isLoadingOverlayVisible = true
                    return .cancel(id: CancelID.overlayDelay)

                case .connected:
                    return .run { send in
                        try await clock.sleep(for: .seconds(3))
                        await send(.connectedOverlayDelayElapsed)
                    }
                    .cancellable(id: CancelID.overlayDelay, cancelInFlight: true)

                case .disconnecting, .disconnected:
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

                    if case .connected = connectionState {
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

            case let .tabChanged(tab):
                state.selectedTab = tab
                return .none

            case .expandButtonTapped:
                state.expandState = state.expandState == .compact ? .expanded : .compact
                return .none

            case let .connectionCommandReceived(.connect(spec, connectionProtocol, trigger)):
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol ?? propertiesManager.connectionProtocol
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.disconnect(trigger, completion)):
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(trigger)
                    await send(.connection(.input(.disconnect)))
                    await completion?()
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case .connectionCommandReceived(.retry):
                let spec = propertiesManager.lastConnectionIntent
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: propertiesManager.connectionProtocol
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.reconnect(connectionProtocol)):
                let spec = propertiesManager.lastConnectionIntent
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol ?? propertiesManager.connectionProtocol
                )
                return .run { send in
                    AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                    await send(.connection(.input(.connect(intent))))
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.applySettings(settings)):
                let hasPortForwardingChange = settings.contains {
                    if case .portForwarding = $0 {
                        return true
                    }
                    return false
                }
                return .merge(
                    .send(.connection(.input(.applySettings(settings)))),
                    hasPortForwardingChange ? .send(.syncNATPortMappingState) : .none
                )

            case let .connectionCommandReceived(.clearConnectionData(completion)):
                return .run { send in
                    await send(.connection(.input(.onLogout)))
                    await completion?()
                }

            case .countriesSection(.delegate(.openProfilesTab)):
                state.selectedTab = .profiles
                return .none

            case .countriesSection:
                return .none

            case let .connection(.delegate(.connectionFailed(error))):
                SentryHelper.shared?.log(error: error)
                return .none // .run { _ in await alertService.feed(error) }

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
                return .run { [pushAlert] send in
                    let alert: SystemAlert = switch resolutionError {
                    case .secureCoreUnavailable:
                        SecureCoreUpsellAlert()
                    case let .specificCountryUnavailable(countryCode):
                        CountryUpsellAlert(countryCode: countryCode)
                    case let .serverChangeUnavailable(until, duration, exhaustedSkips):
                        ConnectionCooldownAlert(until: until, duration: duration, longSkip: exhaustedSkips) {
                            Task { [intent, send] in
                                await send(.connection(.input(.connect(intent))))
                            }
                        }
                    }
                    pushAlert(alert)
                }

            case .connection:
                return .none
            }
        }
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
        case connectionCommandEffect
        case plutoniumSync
    }
}

private extension SidebarFeature {
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
        if case .connected = connectionState {
            return true
        }
        return false
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
