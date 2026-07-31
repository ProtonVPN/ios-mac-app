//
//  Created on 28/07/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Domain
import Home
import HomeShared
import VPNAppCore

/// The tabular app's shell, above the tabs. The globe and the connection chrome are the backdrop, and the tabs ride
/// over them in a sheet the user can raise and lower, so how much map is visible is shell state rather than anything a
/// tab owns.
///
/// Home, Countries, Profiles and Settings remain the tab pages they already were. Only the two children that draw
/// behind them live here, along with the handful of decisions that need to see both the backdrop and a page at once.
/// Living above every tab feature is what lets it take more of them as children later without any of them depending on
/// the shell.
@Reducer
public struct TabularFeature {
    /// How far the sheet is raised, and with it how much of the globe shows. One ladder for every tab, declared in
    /// height order.
    public enum Detent: Equatable, CaseIterable {
        /// Minimized to its bar. The globe is effectively the screen, and the location pins are in hand.
        case bar
        /// Half the room: the page above, the globe centered on the connection below.
        case half
        /// Raised over the map.
        case full
    }

    /// Ordered as the tab bar presents them.
    public enum Tab: Equatable, CaseIterable {
        case home
        case countries
        case profiles
        case settings
    }

    @ObservableState
    public struct State: Equatable {
        public internal(set) var detent: Detent = .half
        public internal(set) var tab: Tab = .home
        /// Whether the visible tab has moved into a menu. The legacy detail pages are still designed for the whole
        /// screen, so while one is up the sheet's only stop is full.
        public internal(set) var isPageDeep = false

        public var commands: ConnectionCommandsFeature.State
        public var connectionStatus: ConnectionStatusFeature.State
        public var home: HomeFeature.State
        public var map: HomeMapFeature.State

        public init(detent: Detent = .half) {
            self.commands = .init()
            self.connectionStatus = .init()
            self.home = .init()
            self.map = .init()
            self.detent = detent
        }
    }

    public enum Action {
        case commands(ConnectionCommandsFeature.Action)
        case connectionStatus(ConnectionStatusFeature.Action)
        /// The sheet came to rest at a new detent, or a policy below moved it.
        case detentChanged(Detent)
        case home(HomeFeature.Action)
        case map(HomeMapFeature.Action)
        /// The visible tab's navigation depth changed: pushed beyond its root, or back at it.
        case pageDepthChanged(Bool)
        case tabSelected(Tab)
    }

    @Dependency(\.connectionCommandClient) private var connectionCommandClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.commands, action: \.commands) {
            ConnectionCommandsFeature()
        }
        Scope(state: \.connectionStatus, action: \.connectionStatus) {
            ConnectionStatusFeature()
        }
        Scope(state: \.map, action: \.map) {
            HomeMapFeature()
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {
            case let .detentChanged(detent):
                // If a page is designed for the whole screen, don't let the user collapse the sheet.
                state.detent = state.isPageDeep ? .full : detent
                return .none

            case let .pageDepthChanged(isDeep):
                state.isPageDeep = isDeep
                // If a page is designed for the whole screen, don't let the user collapse the sheet.
                if isDeep {
                    state.detent = .full
                }
                return .none

            case let .tabSelected(tab):
                state.tab = tab
                // Reading a page means raising the sheet off its bar.
                if state.detent == .bar {
                    state.detent = .half
                }
                return .none

            case let .map(.delegate(.connect(spec))):
                // Tapping a location pin connects through the same command pipeline as recents and the card, and drops
                // the sheet so the camera flight to the new country is viewable.
                state.detent = .bar
                connectionCommandClient.send(.connect(spec, nil, .map))
                return .none

            case .map(.mapMoved), .map(.mapBackgroundTapped), .map(.userPinTapped):
                // Touching the map through the half sheet should make it interactive. Collapse the bar, which is
                // monitored elsewhere to make the pins become interactive.
                if state.detent == .half {
                    state.detent = .bar
                }
                return .none

            case .map(.delegate(.showUpsell)):
                return .send(.home(.showUpsell(.allCountries)))

            case let .connectionStatus(.delegate(.upsellTapped(upsellMode))):
                let request: HomeFeature.UpsellRequest = switch upsellMode {
                case .netshield: .netShield
                case .serverChange: .allCountries
                }
                return .send(.home(.showUpsell(request)))

            case .commands(.commandReceived(.connect)):
                // A connect that starts under the fully raised sheet lowers it to half, so the status view and the
                // camera flight come into view without the user having to clear the sheet themselves.
                if state.detent == .full, !state.isPageDeep {
                    state.detent = .half
                }
                return .none

            case let .commands(.delegate(delegated)):
                // The machinery's Home-bound requests: their destinations live in Home's tree, so the
                // shell only routes.
                switch delegated {
                case let .connectionFailed(error):
                    return .send(.home(.connectionFailed(error)))
                case let .intentResolutionFailed(resolutionError):
                    return .send(.home(.intentResolutionFailed(resolutionError)))
                case let .twoFactorRequired(error):
                    return .send(.home(.twoFactorRequired(error)))
                }

            case .commands, .connectionStatus, .home, .map:
                return .none
            }
        }
    }
}
