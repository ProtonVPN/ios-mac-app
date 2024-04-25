//
//  Created on 2023-05-11.
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

#if os(macOS)
import Foundation
import ComposableArchitecture
import SwiftUI

@Reducer
struct ReportBugFeatureMacOS: Reducer {

    @ObservableState
    struct State {

        var steps: UInt = 3
        var step: UInt {
            if step4State != nil {
                return 0
            } else if step3aState != nil || step3bState != nil {
                return 3
            } else if step2State != nil {
                return 2
            }
            return 1

        }

        // We have two possible paths: 1st with quick fixes view and 2nd that goes
        // straight to contact form. Depending on the path contact form store may be
        // saved directly in this store (path 1) or as a route inside step1 store.
        //
        // 1) step1 -> step2 -> step3a -> step4
        // 2) step1 ->          step3b -> step4
        //

        var step1State: WhatsTheIssueFeature.State

        var step2State: QuickFixesFeature.State? {
            get {
                guard let route = step1State.route else {
                    return nil
                }
                switch route {
                case .quickFixes(let state):
                    return state
                case .contactForm(_):
                    return nil
                }
            }
            set {
                if let newValue {
                    step1State.route = .quickFixes(newValue)
                } else {
                    step1State.route = nil
                }
            }
        }

        var step3aState: ContactFormFeature.State?

        var step3bState: ContactFormFeature.State? {
            get {
                guard let route = step1State.route else {
                    return nil
                }
                switch route {
                case .quickFixes(_):
                    return nil
                case .contactForm(let state):
                    return state
                }
            } set {
                if let newValue {
                    step1State.route = .contactForm(newValue)
                } else {
                    step1State.route = nil
                }
            }
        }

        private var step3State: ContactFormFeature.State? {
            step3aState ?? step3bState
        }

        var step4State: BugReportResultFeature.State? {
            get {
                step3State?.resultState
            }
            set {
                step3aState?.resultState = newValue
            }
        }

        init(whatsTheIssueState: WhatsTheIssueFeature.State) {
            self.step1State = whatsTheIssueState
        }
    }

    enum Action {
        case backPressed
        case step1(WhatsTheIssueFeature.Action)
        case step2(QuickFixesFeature.Action)
        case step3a(ContactFormFeature.Action)
        case step3b(ContactFormFeature.Action)
        case step4(BugReportResultFeature.Action)
    }

    public enum ContactFormParent {
        case whatsTheIssue
        case quickFixes
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.step1State, action: /Action.step1) {
            WhatsTheIssueFeature()
        }
        .ifLet(\.step2State, action: /Action.step2, then: { QuickFixesFeature() })
        .ifLet(\.step3aState, action: /Action.step3a, then: { ContactFormFeature() })
        .ifLet(\.step3bState, action: /Action.step3b, then: { ContactFormFeature() })
        .ifLet(\.step4State, action: /Action.step4, then: { BugReportResultFeature() })

        Reduce { state, action in
            switch action {
            case .step2(.next):
                if let category = state.step2State?.category {
                    state.step3aState = ContactFormFeature.State(
                        fields: category.inputFields,
                        category: category.label
                    )
                }
                return .none

            case .backPressed:
                if state.step3aState != nil {
                    state.step3aState = nil
                    return .none
                } else if state.step3bState != nil {
                    return .send(.step1(.contactFormDeselected))
                } else if state.step2State != nil {
                    return .send(.step1(.quickFixesDeselected))
                }
                return .none

            case .step4(let subAction):
                // "Redirect" action according to the path of the user towards the
                // contact form.
                let newAction = state.step3aState != nil
                    ? Action.step3a(ContactFormFeature.Action.resultViewAction(subAction))
                    : Action.step3b(ContactFormFeature.Action.resultViewAction(subAction))
                return .send(newAction)

            default:
                return .none
            }
        }
    }

}

public struct ReportBugView: View {

    @Perception.Bindable var store: StoreOf<ReportBugFeatureMacOS>
    @Environment(\.colors) var colors: Colors
    @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

    private let verticalPadding = 32.0
    private let horizontalPadding = 126.0

    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {

                if let childStore = store.scope(state: \.step4State, action: \.step4) {
                    BugReportResultView(store: childStore)
                        .padding(.horizontal, horizontalPadding)

                } else {
                    VStack(alignment: .leading, spacing: 0) {

                        Button("", action: { store.send(.backPressed, animation: .default) })
                            .buttonStyle(BackButtonStyle())
                            .opacity(store.step > 1 ? 1 : 0)

                        StepProgress(step: store.step, steps: store.steps, colorMain: colors.primary, colorText: colors.textAccent, colorSecondary: colors.backgroundStrong ?? colors.backgroundWeak)
                            .padding(.bottom)
                            .transition(.opacity)

                        UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)
                    }
                    .transition(.opacity)
                    .padding(.horizontal, horizontalPadding)

                    ScrollView {
                        if let childStore = store.scope(state: \.step3aState, action: \.step3a) {
                            ContactFormView(store: childStore)

                        } else if let childStore = store.scope(state: \.step3bState, action: \.step1.route.contactForm) {
                            ContactFormView(store: childStore)

                        } else if let childStore = store.scope(state: \.step2State, action: \.step2) {
                            QuickFixesView(store: childStore)

                        } else {
                            let childStore = store.scope(state: \.step1State, action: \.step1)
                            WhatsTheIssueView(store: childStore)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
            .padding(.top, verticalPadding)
            .background(colors.background)

        }
    }
}

struct ReportBugView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let state = ReportBugFeatureMacOS.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeatureMacOS()

        return Group {
            ReportBugView(store: Store(initialState: state, reducer: { reducer }))
                .frame(width: 600, height: 600)
        }
    }
}

#endif
