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

/// Some business logic requires communication between reducers. This is facilitated by the parent feature, which
/// listens to actions coming from one child, and sends the relevant action to the other child. This allows features to
/// function independently in completely separate modules.
///
/// For example, for the sign-in flow:
///
/// ```
/// AppFeature {
///     SessionNetworkingFeature,
///     SignInFeature,
///     MainFeature { ... }
/// }
/// ```
///
/// If `SignInFeature` is responsible for logging in the user. Once the user has been signed in, it can send an action
/// such as `signInFinished(credentials: AuthCredentials)`. This is a delegate action that isn't handled by the
/// `SignInFeature`, but is instead handled by the `AppFeature`, which passes  a `SessionNetworkingFeature` action.
///
/// The reverse of this flow is used for logging out, where a user action from the `MainFeature` is observed by the
/// `AppFeature`, at which it sends a `SessionNetworkingFeature.Action` which is handled by the `SessionNetworkingFeature`
@Reducer
struct AppFeature {
    @Dependency(\.alertService) var alertService

    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Shared(.userTier) var userTier: Int?
        var main = MainFeature.State()
        var welcome = WelcomeFeature.State()

        @Presents var alert: AlertState<Action.Alert>?

        /// Determines whether we show the `MainFeature` or `WelcomeFeature` (sign in flow)
        var networking: SessionNetworkingFeature.State = .unauthenticated(nil)
    }

    enum Action {
        case main(MainFeature.Action)
        case welcome(WelcomeFeature.Action)

        case onAppearTask

        case incomingAlert(AlertService.Alert)
        case alert(PresentationAction<Alert>)

        case networking(SessionNetworkingFeature.Action)

        @CasePathable
        enum Alert {
            case errorMessage
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.networking, action: \.networking) {
            SessionNetworkingFeature()
        }
        Scope(state: \.welcome, action: \.welcome) {
            WelcomeFeature()
        }
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppearTask:
                var effects: [Effect<AppFeature.Action>] = [
                    .run { send in
                        for await alert in await alertService.alerts() {
                            await send(.incomingAlert(alert))
                        }
                    }]
                if case .unauthenticated = state.networking {
                    effects.insert(.send(.networking(.startAcquiringSession)), at: 0)
                }

                return .merge(effects)

            case .main(.settings(.alert(.presented(.signOut)))):
                // Send an action to inform SessionNetworkingFeature, which will clear keychains and acquire unauth session
                return .concatenate(
                    .send(.main(.onLogout)),
                    .send(.networking(.startLogout))
                )

            case .main:
                return .none

            case .welcome(.destination(.presented(.signIn(.signInFinished(.success(let credentials)))))):
                state.main.currentTab = .home
                return .send(.networking(.forkedSessionAuthenticated(.success(credentials))))

            case .welcome(.destination(.presented(.signIn(.signInFinished(.failure))))):
                return .none

            case .welcome:
                return .none

            case .networking(.startLogout):
                state.welcome = .init() // Reset welcome state
                return .none

            case .networking(.delegate(.tier(let tier))):
                state.userTier = tier
                return .none

            case .networking(.delegate(.displayName(let name))):
                state.userDisplayName = name
                return .none
            case .networking:
                return .none

            case .incomingAlert(let alert):
                state.alert = alert.alertState(from: Action.Alert.self)
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
