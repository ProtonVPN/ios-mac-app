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
import PaymentsShared
import Persistence
import SwiftUI
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
    /// How far the sheet is raised, and with it how much of the globe shows. Ordered by height rather than
    /// alphabetically: the cases describe one ordinal axis, so reading them in size order is what makes the
    /// transitions legible.
    public enum Detent: Equatable {
        /// Minimized to its bar. The globe is effectively the screen.
        case bar
        case half
        /// Raised over the map.
        case full
    }

    @ObservableState
    public struct State: Equatable {
        public internal(set) var detent: Detent = .half

        public var connectionStatus: ConnectionStatusFeature.State
        public var home: HomeFeature.State
        public var map: HomeMapFeature.State

        public init(detent: Detent = .half) {
            self.detent = detent
            self.connectionStatus = .init()
            self.home = .init()
            self.map = .init()
        }
    }

    public enum Action {
        case connectionStatus(ConnectionStatusFeature.Action)
        /// The sheet came to rest at a new detent, or a policy below moved it.
        case detentChanged(Detent)
        case home(HomeFeature.Action)
        case map(HomeMapFeature.Action)
        /// A tab was chosen. Which tab is showing stays with the tab controller, so this carries no payload:
        /// the shell only needs to know the event happened.
        case tabSelected
    }

    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.serverRepository) private var serverRepository

    public init() {}

    public var body: some Reducer<State, Action> {
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
                state.detent = detent
                return .none

            case .tabSelected:
                // Reading a page means raising the sheet off its bar first.
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

            case .map(.delegate(.showUpsell)):
                // Choosing a location is paid. The payments destination lives in Home's tree, so the
                // request is forwarded rather than answered here.
                return .send(.home(.showUpsell(allCountriesUpsellModalType())))

            case let .connectionStatus(.connectionStatusBanner(.delegate(.upsellTapped(mode)))):
                let type: UpsellModalType = switch mode {
                case .netshield: .netShield
                case .serverChange: allCountriesUpsellModalType()
                }
                return .send(.home(.showUpsell(type)))

            case .connectionStatus, .home, .map:
                return .none
            }
        }
    }

    private func allCountriesUpsellModalType() -> UpsellModalType {
        .allCountries(
            numberOfServers: serverRepository.roundedServerCount,
            numberOfCountries: serverRepository.countryCount()
        )
    }
}
