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
    struct Environment {
        var persistMapWidth: @Sendable (Int) -> Void
    }

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
    }

    enum Action {
        case viewDidLoad
        case viewDidAppear
        case mouseDown
        case startObservingEvents

        case windowDidResize(width: CGFloat)
        case windowDidEndLiveResize(width: CGFloat, isFullscreen: Bool)
        case windowWillEnterFullScreen
        case windowWillExitFullScreen
        case occlusionStateChanged(isVisible: Bool)
        case appStateChanged(AppState)

        case tabChanged(SidebarTab)
        case expandButtonTapped

        case countriesSection(CountriesSectionFeature.Action)
    }

    private let quickSettingsEnvironment: QuickSettingsFeature.Environment
    private let environment: Environment
    private let sidebarWidth: CGFloat
    private let expandButtonWidth: CGFloat
    @Dependency(\.sidebarEventsClient) private var sidebarEventsClient

    init(
        quickSettingsEnvironment: QuickSettingsFeature.Environment,
        environment: Environment,
        sidebarWidth: CGFloat,
        expandButtonWidth: CGFloat
    ) {
        self.quickSettingsEnvironment = quickSettingsEnvironment
        self.environment = environment
        self.sidebarWidth = sidebarWidth
        self.expandButtonWidth = expandButtonWidth
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.countriesSection, action: \.countriesSection) {
            CountriesSectionFeature(quickSettingsEnvironment: quickSettingsEnvironment)
        }

        Reduce { state, action in
            switch action {
            case .viewDidLoad:
                state.selectedTab = .countries
                return .send(.startObservingEvents)

            case .startObservingEvents:
                return .merge(
                    .run { send in
                        for await appState in sidebarEventsClient.appStateChanged() {
                            await send(.appStateChanged(appState))
                        }
                    }
                    .cancellable(id: CancelID.appState),
                    .run { send in
                        for await tab in sidebarEventsClient.tabChanged() {
                            await send(.tabChanged(tab))
                        }
                    }
                    .cancellable(id: CancelID.tab),
                    .run { send in
                        for await width in sidebarEventsClient.windowDidResize() {
                            await send(.windowDidResize(width: width))
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

            case let .windowDidResize(width):
                state.expandState = width <= sidebarWidth + expandButtonWidth ? .compact : .expanded
                return .none

            case let .windowDidEndLiveResize(width, isFullscreen):
                state.expandState = width <= sidebarWidth + expandButtonWidth ? .compact : .expanded
                guard !isFullscreen, state.expandState == .expanded, width > sidebarWidth + expandButtonWidth else {
                    return .none
                }
                let mapWidth = Int(width - sidebarWidth)
                state.mapWidth = CGFloat(mapWidth)
                environment.persistMapWidth(mapWidth)
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
                case .connected, .disconnected:
                    state.isLoadingOverlayVisible = false
                case let .aborted(userInitiated):
                    if userInitiated {
                        state.isLoadingOverlayVisible = false
                    }
                default:
                    break
                }
                return .none

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
        case tab
        case windowResize
        case windowEndResize
        case windowEnterFullScreen
        case windowExitFullScreen
        case occlusion
    }
}
