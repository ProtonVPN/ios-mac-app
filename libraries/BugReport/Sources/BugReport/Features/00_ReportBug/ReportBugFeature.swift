//
//  Created on 14/08/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Foundation
import Strings
import SwiftUI

@Reducer
struct ReportBugFeature {
    @Reducer(state: .equatable)
    enum Path {
        case quickFixes(QuickFixesFeature)
        case contactUs(ContactFormFeature)
        case result(BugReportResultFeature)
    }

    @ObservableState
    struct State: Equatable {
        let steps: UInt = 3

        var path = StackState<Path.State>()
        var whatsTheIssueState: WhatsTheIssueFeature.State

        @Presents package var alert: AlertState<Action.Alert>?
    }

    @CasePathable
    enum Action {
        case path(StackActionOf<Path>)
        case whatsTheIssueAction(WhatsTheIssueFeature.Action)
        case alert(PresentationAction<Alert>)
        case attemptContactUs(Category)

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
        Scope(state: \.whatsTheIssueState, action: \.whatsTheIssueAction) {
            WhatsTheIssueFeature()
        }

        Reduce { state, action in
            switch action {
            case let .whatsTheIssueAction(.categorySelected(category)):
                if let suggestions = category.suggestions, !suggestions.isEmpty {
                    state.path.append(.quickFixes(QuickFixesFeature.State(category: category)))
                    return .none
                }
                return .send(.attemptContactUs(category))

            case let .path(.element(id: id, action: .quickFixes(.contactUs))):
                guard let quickFixes = state.path[id: id]?.quickFixes else { return .none }
                return .send(.attemptContactUs(quickFixes.category))

            case let .path(.element(id: _, action: .contactUs(.sendResponseReceived(response)))):
                var error: String?
                if case let .failure(someError) = response {
                    error = someError.localizedDescription
                }
                state.path.append(.result(BugReportResultFeature.State(error: error)))
                return .none

            case .path:
                return .none

            case let .attemptContactUs(category):
                guard !isUserCredentialless() else {
                    state.alert = signInAlert
                    return .none
                }
                state.path.append(.contactUs(ContactFormFeature.State(fields: category.inputFields, category: category.label)))
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

            case .whatsTheIssueAction:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
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

extension ReportBugFeature.State {
    var currentStep: UInt {
        // starting point on what's the issue
        if path.isEmpty {
            return 1
        }
        // either quick fixes or contact form
        if path.count == 1 {
            if path.last?.hasQuickFixes == true {
                return 2
            }
            // no quick fixes, only contact form
            if path.last?.hasContactUs == true {
                return 3
            }
        }
        // quick fixes + contact form, **not** contact form + result
        if path.count == 2, path.last?.hasResult == false {
            return 3
        }
        return 0
    }
}

extension ReportBugFeature.Path.State {
    var hasQuickFixes: Bool {
        switch self {
        case .quickFixes: true
        default: false
        }
    }

    var hasContactUs: Bool {
        switch self {
        case .contactUs: true
        default: false
        }
    }

    var hasResult: Bool {
        switch self {
        case .result: true
        default: false
        }
    }
}
