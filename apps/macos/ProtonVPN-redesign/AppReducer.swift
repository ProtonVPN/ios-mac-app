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

import Foundation
import ComposableArchitecture
import Home
import Home_macOS

public struct LoginFeature: ReducerProtocol {
    public struct State: Equatable {
        var isLoggedIn = false
        var initialError: String?
    }

    public enum Action: Equatable {
        case loginButtonPressed(username: String, password: String)
    }

    public var body: some ReducerProtocolOf<LoginFeature> {
        Reduce { state, action in
            switch action {
            case .loginButtonPressed:
                return .none
            }
        }
    }
}

struct AppReducer: ReducerProtocol {

    public typealias ActionSender = (Action) -> Void
    
    struct State: Equatable {
        public var login: LoginFeature.State
        public var home: HomeFeature.State
        public var connectionDetailsVisible: Bool
//        public var countries: CountriesFeature.State
//        public var settings: SettingsFeature.State
    }

    enum Action: Equatable {
        case showLogin(initialError: String?)
        case showSideBar
        case login(LoginFeature.Action)
        case home(HomeFeature.Action)
    }

    var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .home(.connect(let specs)):
                return .run { _ in
                    @Dependency(\.connectToVPN) var connectToVPN
                    try? await connectToVPN(specs)
                }

            case .home(.disconnect):
                return .run { _ in
                    @Dependency(\.disconnectVPN) var disconnectVPN
                    try? await disconnectVPN()
                }

            case .home:
                return .none
            case .toggleConnectionDetails:
                state.connectionDetailsVisible.toggle()
                return .none
            case .home:
                return .none
            case .showLogin(let initialError):
                state.login.initialError = initialError
                state.login.isLoggedIn = false
                return .none
            case .showSideBar:
                state.login.isLoggedIn = true
                return .none
            case .login:
                return .none
            }
        }
        Scope(state: \.home, action: /Action.home) {
            HomeFeature()
        }
        Scope(state: \.login, action: /Action.login) {
            LoginFeature()
        }
    }
}
