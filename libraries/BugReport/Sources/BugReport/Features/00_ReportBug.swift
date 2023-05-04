//
//  Created on 2023-05-04.
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
import SwiftUI
import SwiftUINavigation

#if os(iOS)
struct ReportBugFeatureiOS: Reducer {

    struct State: Equatable {
        var whatsTheIssueState: WhatsTheIssueFeature.State
    }

    enum Action: Equatable {
        case whatsTheIssueAction(WhatsTheIssueFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.whatsTheIssueState, action: /Action.whatsTheIssueAction) {
            WhatsTheIssueFeature()
        }
    }

}

public struct ReportBugView: View {

    let store: StoreOf<ReportBugFeatureiOS>

    @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel
    @Environment(\.colors) var colors: Colors

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in
            NavigationView {
                WhatsTheIssueView(store: self.store.scope(state: \.whatsTheIssueState, action: ReportBugFeatureiOS.Action.whatsTheIssueAction))
            }
            .navigationViewStyle(.stack)
        })
    }
}

#elseif os(macOS)

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

        var currentPage: Page {
            if let contactFormState = whatsTheIssueState.contactFormState {
                if let resultState = contactFormState.resultState {
                    return .result(resultState, .whatsTheIssue)
                }
                return .contactForm(contactFormState, .whatsTheIssue)
            }
            if let quickFixesState = whatsTheIssueState.quickFixesState {
                if let contactFormState = quickFixesState.contactFormState {
                    if let resultState = contactFormState.resultState {
                        return .result(resultState, .quickFixes)
                    }
                    return .contactForm(contactFormState, .quickFixes)
                }
                return .quickFixes(quickFixesState)
            }
            return .whatsTheIssue(whatsTheIssueState)
        }

    }

    enum Action: Equatable {
        case backPressed
        case whatsTheIssueAction(WhatsTheIssueFeature.Action)
    }

    enum Page {
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
        Reduce { state, action in
            switch action {
            case .backPressed:
                if nil != state.whatsTheIssueState.quickFixesState {
                    if nil != state.whatsTheIssueState.quickFixesState?.contactFormState {
                        state.whatsTheIssueState.quickFixesState?.contactFormState = nil
                    } else {
                        state.whatsTheIssueState.quickFixesState = nil
                    }
                } else if nil != state.whatsTheIssueState.contactFormState {
                    state.whatsTheIssueState.contactFormState = nil
                }
                return .none

            default:
                return .none
            }
        }
        Scope(state: \.whatsTheIssueState, action: /Action.whatsTheIssueAction) {
            WhatsTheIssueFeature()
        }
    }

}

public struct ReportBugView: View {

    let store: StoreOf<ReportBugFeatureMacOS>
    @Environment(\.colors) var colors: Colors
    @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

    private let verticalPadding = 64.0
    private let horizontalPadding = 126.0

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in

            VStack(alignment: .leading, spacing: 0) {

                if case .result(let state, let parent) = viewStore.currentPage {
                    BugReportResultView(store: self.store.scope(state: { _ in state },
                                                                action: {
                        switch parent {
                        case .whatsTheIssue:
                            return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.contactFormAction(.resultViewAction($0)))
                        case .quickFixes:
                            return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.quickFixesAction(.contactFormAction(.resultViewAction($0))))
                        }
                    }))
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, verticalPadding)

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
                                                                   action: { ReportBugFeatureMacOS.Action.whatsTheIssueAction(.quickFixesAction($0)) }))
                            
                        case .contactForm(let state, let parent):
                            ContactFormView(store: self.store.scope(state: { _ in state },
                                                                    action: {
                                switch parent {
                                case .whatsTheIssue:
                                    return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.contactFormAction($0))
                                case .quickFixes:
                                    return ReportBugFeatureMacOS.Action.whatsTheIssueAction(.quickFixesAction(.contactFormAction($0)))
                                }
                            }))
                            
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, verticalPadding)
                    
                }
            }
            .padding(.top, verticalPadding)
            .background(colors.background)

        })
    }
}

#endif

// MARK: - Preview

struct ReportBugView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        #if os(iOS)
        let state = ReportBugFeatureiOS.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeatureiOS()

        #elseif os(macOS)
        let state = ReportBugFeatureMacOS.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeatureMacOS()
        #endif

        return Group {
            ReportBugView(store: Store(initialState: state, reducer: reducer))
        }
    }
}
