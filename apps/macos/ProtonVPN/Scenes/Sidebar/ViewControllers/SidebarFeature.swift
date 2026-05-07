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
import Connection
import CoreGraphics
import Domain
import Foundation
import LegacyCommon
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
    @Dependency(\.connectToVPN) private var connectToVPN
    @Dependency(\.disconnectVPN) private var disconnectVPN
    @Dependency(\.propertiesManager) private var propertiesManager
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
                    .cancellable(id: CancelID.connectionCommands)
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
                return .run { _ in
                    try? await connectToVPN(spec, connectionProtocol, trigger)
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.disconnect(trigger, completion)):
                return .run { _ in
                    try? await disconnectVPN(trigger)
                    await completion?()
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case .connectionCommandReceived(.retry):
                let spec = propertiesManager.lastConnectionIntent
                return .run { _ in
                    try? await connectToVPN(spec, propertiesManager.connectionProtocol, .auto)
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

            case let .connectionCommandReceived(.reconnect(connectionProtocol)):
                let spec = propertiesManager.lastConnectionIntent
                return .run { _ in
                    try? await connectToVPN(spec, connectionProtocol ?? propertiesManager.connectionProtocol, .auto)
                }
                .cancellable(id: CancelID.connectionCommandEffect, cancelInFlight: true)

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
                return .send(.vpnConnectionStatusUpdated(connectionState.vpnConnectionStatus(
                    fallbackSpec: fallbackSpec,
                    previousStatus: state.vpnConnectionStatus
                )))

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
        case connectionCommandEffect
    }
}
