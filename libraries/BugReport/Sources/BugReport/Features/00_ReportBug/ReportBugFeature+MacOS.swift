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

    struct State: Equatable {
        var whatsTheIssueState: WhatsTheIssueFeature.State

        var steps: UInt = 3
        var step: UInt {
            switch currentPage {
            case .whatsTheIssue:    return 1
            case .quickFixes:       return 2
            case .contactForm:      return 3
            case .result:           return 0
            }
        }

        init(whatsTheIssueState: WhatsTheIssueFeature.State) {
            self.whatsTheIssueState = whatsTheIssueState
            self.currentPage = .whatsTheIssue(whatsTheIssueState)
        }

        var currentPage: Page

        /// Map state to the page that should be displayed
        fileprivate func currentPageNow() -> Page {
            guard let route = whatsTheIssueState.route else {
                return .whatsTheIssue(whatsTheIssueState)
            }

            switch route {
            case .contactForm(let contactFormState):
                if let resultState = contactFormState.resultState {
                    return .result(resultState, .whatsTheIssue)
                }
                return .contactForm(contactFormState, .whatsTheIssue)

            case .quickFixes(let quickFixesState):
                if let contactFormState = quickFixesState.contactFormState {
                    if let resultState = contactFormState.resultState {
                        return .result(resultState, .quickFixes)
                    }
                    return .contactForm(contactFormState, .quickFixes)
                }
                return .quickFixes(quickFixesState)
            }
        }

    }

    enum Action: Equatable {
        case backPressed
        case whatsTheIssueAction(WhatsTheIssueFeature.Action)
    }

    enum Page: Equatable {
        case whatsTheIssue(WhatsTheIssueFeature.State)
        case quickFixes(QuickFixesFeature.State)
        case contactForm(ContactFormFeature.State, ContactFormParent)
        case result(BugReportResultFeature.State, ContactFormParent)

        enum ContactFormParent {
            case whatsTheIssue
            case quickFixes
        }
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.whatsTheIssueState, action: /Action.whatsTheIssueAction) {
            WhatsTheIssueFeature()
        }
        Reduce { state, action in
            switch action {
            case .backPressed:
                guard let route = state.whatsTheIssueState.route else {
                    return .none
                }

                switch route {
                case .quickFixes(let quickFixesState):
                    if quickFixesState.contactFormState != nil {
                        return .send(.whatsTheIssueAction(.route(.quickFixes(.contactFormDeselected))))
                    } else {
                        return .send(.whatsTheIssueAction(.quickFixesDeselected))
                    }

                case .contactForm:
                    return .send(.whatsTheIssueAction(.contactFormDeselected))
                }

            default:
                state.currentPage = state.currentPageNow()
                return .none
            }
        }
    }

}

public struct ReportBugView: View {

    let store: StoreOf<ReportBugFeatureMacOS>
    @Environment(\.colors) var colors: Colors
    @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

    private let verticalPadding = 32.0
    private let horizontalPadding = 126.0

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in

            VStack(alignment: .leading, spacing: 0) {

                if case .result(let state, let parent) = viewStore.currentPage {
                    BugReportResultView(store: self.store.scope(state: { _ in state },
                                                                action: {
                        switch parent {
                        case .whatsTheIssue:
                            return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.route(.contactForm(.resultViewAction($0))))
                        case .quickFixes:
                            return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.route(.quickFixes(.contactFormAction(.resultViewAction($0)))))
                        }
                    }))

                } else {
                    VStack(alignment: .leading, spacing: 0) {

                        Button("", action: { viewStore.send(.backPressed, animation: .default) })
                            .buttonStyle(BackButtonStyle())
                            .opacity(viewStore.step > 1 ? 1 : 0)

                        StepProgress(step: viewStore.step, steps: viewStore.steps, colorMain: colors.primary, colorText: colors.textAccent, colorSecondary: colors.backgroundStrong ?? colors.backgroundWeak)
                            .padding(.bottom)
                            .transition(.opacity)

                        UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)
                    }
                    .transition(.opacity)
                    .padding(.horizontal, horizontalPadding)

                    ScrollView {
                        switch viewStore.currentPage {
                        case .whatsTheIssue(let state):
                            WhatsTheIssueView(store: self.store.scope(state: { _ in state },
                                                                      action: ReportBugFeatureMacOS.Action.whatsTheIssueAction))

                        case .quickFixes(let state):
                            QuickFixesView(store: self.store.scope(state: { _ in state },
                                                                   action: { ReportBugFeatureMacOS.Action.whatsTheIssueAction(.route(.quickFixes($0))) }))

                        case .contactForm(let state, let parent):
                            ContactFormView(store: self.store.scope(state: { _ in state },
                                                                    action: {
                                switch parent {
                                case .whatsTheIssue:
                                    return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.route(.contactForm($0)))
                                case .quickFixes:
                                    return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.route(.quickFixes(.contactFormAction($0))))
                                }
                            }))

                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                }
            }
            .padding(.top, verticalPadding)
            .background(colors.background)

        })
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
