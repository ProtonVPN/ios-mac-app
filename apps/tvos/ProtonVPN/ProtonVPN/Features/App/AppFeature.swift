//
//  Created on 25/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

import CommonNetworking

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.appStorage("username")) var user: String?
        var main: MainFeature.State = .init()
        var welcome = WelcomeFeature.State()

        var networking: NetworkingFeature.State = .unauthenticated
    }

    enum Action {
        case main(MainFeature.Action)
        case welcome(WelcomeFeature.Action)

        case networking(NetworkingFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.welcome, action: \.welcome) {
            WelcomeFeature()
        }
        Scope(state: \.networking, action: \.networking) {
            NetworkingFeature()
        }
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        Reduce { state, action in
            switch action {
            case .main(.settings(.alert(.presented(.signOut)))):
                // Send an action to inform NetworkingFeature, which will clear keychains and acquire unauth session
                return .run { send in await send(.networking(.startAcquiringSession))}

            case .main:
                return .none

            case .welcome(.destination(.presented(.signIn(.signInFinished(.success(let credentials)))))):
                state.main.currentTab = .home
                return .run { send in await send(.networking(.forkedSessionAuthenticated(.success(credentials)))) }

            case .welcome(.destination(.presented(.signIn(.signInFinished(.failure))))):
                return .none

            case .welcome:
                return .none

            case .networking:
                return .none
            }
        }
    }
}
