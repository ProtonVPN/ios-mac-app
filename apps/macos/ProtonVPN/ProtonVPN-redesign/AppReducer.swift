//
//  Created on 13/07/2023.
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

import Foundation
import ComposableArchitecture
import Home
import Home_macOS
import VPNAppCore

struct AppReducer: ReducerProtocol {

    public typealias ActionSender = (Action) -> Void

    @Dependency(\.initialStateProvider) var initialStateProvider

    enum State: Equatable {
        case loading
        case notLoggedIn(LoginFeature.State)
        case loggedIn(SidebarReducer.State)
    }

    enum Action: Equatable {
        case showLogin(LoginFeature.Action)
        case logIn(LoginFeature.State)
        case loggedIn(SidebarReducer.State)
        case app(SidebarReducer.Action)
    }

    var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .showLogin:
                state = .notLoggedIn(.init())
                return .none
            case .logIn:
                guard case .notLoggedIn = state else { return .none }
                return .run { send in await send(.loggedIn(initialStateProvider.initialState)) }
            case let .loggedIn(appState):
                state = .loggedIn(appState)
                return .none
            case .app: return .none // App actions are handled by the SidebarReducer
            }
        }
        .ifCaseLet(/State.loggedIn, action: /Action.app) {
            SidebarReducer()
                .dependency(\.vpnConnectionStatusPublisher, VPNConnectionStatusPublisherKey.watchVPNConnectionStatusChanges)
                ._printChanges()
        }
    }
}

#endif
