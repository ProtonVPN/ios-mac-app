//
//  Created on 2023-04-27.
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

import ComposableArchitecture
import Foundation
import Strings
import SwiftUI

@Reducer
struct QuickFixesFeature {
    @ObservableState
    struct State: Equatable {
        var category: Category

        @Presents package var alert: AlertState<Action.Alert>?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)
        case attemptContactUs
        case contactUs

        @CasePathable
        enum Alert {
            case createAccount
            case signIn
            case cancel
        }
    }

    @Dependency(\.isUserCredentialless) private var isUserCredentialless
    @Dependency(\.createAccount) private var createAccount
    @Dependency(\.signIn) private var signIn

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .attemptContactUs:
                if isUserCredentialless() {
                    state.alert = signInAlert
                    return .none
                }
                return .send(.contactUs)

            case .contactUs:
                return .none

            case .alert(.presented(.createAccount)):
                // trigger dependency to show create account in navigation service
                return .run { _ in
                    createAccount()
                }

            case .alert(.presented(.signIn)):
                // trigger dependency to show sign in in navigation service
                return .run { _ in
                    signIn()
                }

            case .alert:
                return .none

            case .binding:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private var signInAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.createAccountReportAnIssueGuestMode) },
            actions: {
                ButtonState(action: .send(.createAccount), label: { TextState(Localizable.createAccountReportAnIssueGuestModeCreateAccountButton) })
                ButtonState(action: .send(.signIn), label: { TextState(Localizable.createAccountReportAnIssueGuestModeSignInButton) })
                ButtonState(role: .cancel, action: .send(.cancel), label: { TextState(Localizable.createAccountReportAnIssueGuestModeCancelButton) })
            }
        )
    }
}
