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

/// Some business logic requires communication between reducers. This is facilitated by the parent feautre, which
/// listens to actions coming from one child, and sends the relevant action to the other child. This allows features to
/// function independently in completely separate modules.
///
/// For example, for the sign-in flow:
///
/// ```
/// AppFeature {
///     NetworkingFeature,
///     SignInFeature,
///     MainFeature { ... }
/// }
/// ```
///
/// If `SignInFeature` is responsible for logging in the user. Once the user has been signed in, it can send an action
/// such as `signInFinished(credentials: AuthCredentials)`. This is a delegate action that isn't handled by the
/// `SignInFeature`, but is instead handled by the `AppFeature`, which passes  a `NetworkingFeature` action.
///
/// The reverse of this flow is used for logging out, where a user action from the `MainFeature` is observed by the
/// `AppFeature`, at which it sends a `NetworkingFeature.Action` which is handled by the `NetworkingFeature`
@Reducer struct AppFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.appStorage("username")) var user: String?
        var main: MainFeature.State = .init()
        var welcome = WelcomeFeature.State()

        /// Determines whether we show the `MainFeature` or `WelcomeFeature` (sign in flow)
        var networking: NetworkingFeature.State = .unauthenticated
    }

    enum Action {
        case main(MainFeature.Action)
        case welcome(WelcomeFeature.Action)

        case networking(NetworkingFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.networking, action: \.networking) {
            NetworkingFeature()
        }
        Scope(state: \.welcome, action: \.welcome) {
            WelcomeFeature()
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
