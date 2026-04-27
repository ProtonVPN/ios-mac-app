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
import CoreGraphics
import Domain
import LegacyCommon

@Reducer
struct SidebarFeature {
    @ObservableState
    struct State: Equatable {
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

        var isExpandButtonHidden: Bool { isFullscreen }
        var shouldPresentLoadingOverlay: Bool { isLoadingOverlayVisible && isOccludedVisible }
    }

    enum Action {
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
        case appStateChanged(AppState)

        case tabChanged(SidebarTab)
        case expandButtonTapped

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
        var appStateChanged: @Sendable () -> AsyncStream<AppState>
        var sidebarWidth: CGFloat
        var expandButtonWidth: CGFloat
        var defaultMapWidth: CGFloat
    }

    private let quickSettingsEnvironment: QuickSettingsFeature.Environment
    private let environment: Environment
    @Dependency(\.defaultsProvider) private var defaultsProvider
    @Dependency(\.sidebarEventsClient) private var sidebarEventsClient
    @Dependency(\.continuousClock) private var clock

    var body: some ReducerOf<Self> {
        Scope(state: \.countriesSection, action: \.countriesSection) {
            CountriesSectionFeature(quickSettingsEnvironment: quickSettingsEnvironment)
        }

        Reduce { state, action in
            switch action {
            case .viewDidLoad:
                state.selectedTab = .countries
                let loadedMapWidth = defaultsProvider.getDefaults().integer(forKey: AppConstants.UserDefaults.mapWidth)
                state.mapWidth = loadedMapWidth > Int(environment.expandButtonWidth) ? CGFloat(loadedMapWidth) : environment.defaultMapWidth
                return .send(.startObservingEvents)

            case .startObservingEvents:
                return .merge(
                    .run { send in
                        for await appState in environment.appStateChanged() {
                            await send(.appStateChanged(appState))
                        }
                    }
                    .cancellable(id: CancelID.appState),
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
                    .cancellable(id: CancelID.occlusion)
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

            case let .appStateChanged(appState):
                switch appState {
                case .preparingConnection, .connecting:
                    state.isLoadingOverlayVisible = true
                    return .cancel(id: CancelID.overlayDelay)

                case .connected:
                    return .run { send in
                        try await clock.sleep(for: .seconds(3))
                        await send(.connectedOverlayDelayElapsed)
                    }
                    .cancellable(id: CancelID.overlayDelay, cancelInFlight: true)

                case .disconnected:
                    state.isLoadingOverlayVisible = false
                    return .cancel(id: CancelID.overlayDelay)

                case let .aborted(userInitiated):
                    if userInitiated {
                        state.isLoadingOverlayVisible = false
                        return .cancel(id: CancelID.overlayDelay)
                    }

                default:
                    break
                }
                return .none

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

            case .countriesSection(.delegate(.openProfilesTab)):
                state.selectedTab = .profiles
                return .none

            case .countriesSection:
                return .none
            }
        }
    }

    private enum CancelID {
        case appState
        case windowResize
        case windowEndResize
        case windowEnterFullScreen
        case windowExitFullScreen
        case occlusion
        case overlayDelay
    }
}
