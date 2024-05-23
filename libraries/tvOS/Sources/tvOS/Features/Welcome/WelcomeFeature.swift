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

@Reducer
struct WelcomeFeature {
    @Reducer(state: .equatable)
    enum Destination {
        case signIn(SignInFeature)
        case createAccount(CreateAccountFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case showSignIn
        case showCreateAccount
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .showSignIn:
                state.destination = .signIn(.init(authentication: .loadingSignInCode))
                return .none
            case .showCreateAccount:
                state.destination = .createAccount(.init())
                return .none
            case .destination(.presented(.signIn(.signInFinished(.success(_))))):
                /// Right after logging in, we should reset the state of the welcome page, so that when the user logs out,
                /// the welcome page will be shown, not the sign in page
                state.destination = nil
                return .none
            case .destination(.presented(.signIn(.signInFinished(.failure(.userCancelled))))):
                state.destination = nil
                return .none
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
