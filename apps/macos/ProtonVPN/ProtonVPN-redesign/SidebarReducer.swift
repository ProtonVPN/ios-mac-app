//
//  Created on 21/06/2023.
//
//  Copyright (c) 2023 Proton AG
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

#if REDESIGN

    import ComposableArchitecture
    import Foundation
    import Home
    import VPNAppCore

    @Reducer
    struct SidebarReducer {
        typealias ActionSender = (Action) -> Void

        struct State: Equatable {
            var home: HomeFeature.State
            var connectionDetailsVisible: Bool
//        public var countries: CountriesFeature.State
//        public var settings: SettingsFeature.State
        }

        enum Action: Equatable {
            case home(HomeFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Reduce { _, action in
                switch action {
                case .home:
                    .none
                }
            }
            Scope(state: \.home, action: /Action.home) {
                HomeFeature()
            }
        }
    }

#endif
