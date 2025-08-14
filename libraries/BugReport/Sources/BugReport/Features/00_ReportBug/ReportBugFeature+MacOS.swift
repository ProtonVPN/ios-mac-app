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
    import ComposableArchitecture
    import Foundation
    import SwiftUI

    @Reducer
    struct ReportBugFeatureMacOS {
        @Reducer
        enum Path {
            case quickFixes(QuickFixesFeature)
            case contactUs(ContactFormFeature)
            case result(BugReportResultFeature)
        }

        @ObservableState
        struct State {
            var path = StackState<Path.State>()
            var whatsTheIssueState: WhatsTheIssueFeature.State

            init(whatsTheIssueState: WhatsTheIssueFeature.State) {
                self.whatsTheIssueState = whatsTheIssueState
            }
        }

        @CasePathable
        enum Action {
            case path(StackActionOf<Path>)
            case whatsTheIssueAction(WhatsTheIssueFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: \.whatsTheIssueState, action: \.whatsTheIssueAction) {
                WhatsTheIssueFeature()
            }

            Reduce { state, action in
                switch action {
                case let .whatsTheIssueAction(.categorySelected(category)):
                    if let suggestions = category.suggestions, !suggestions.isEmpty {
                        state.path.append(ReportBugFeatureMacOS.Path.State.quickFixes(
                            QuickFixesFeature.State(category: category)
                        ))
                    } else {
                        state.path.append(ReportBugFeatureMacOS.Path.State.contactUs(ContactFormFeature.State(fields: category.inputFields, category: category.label)))
                    }
                    return .none

                case let .path(.element(id: _, action: .contactUs(.sendResponseReceived(response)))):
                    var error: String?
                    if case let .failure(someError) = response {
                        error = someError.localizedDescription
                    }
                    state.path.append(ReportBugFeatureMacOS.Path.State.result(BugReportResultFeature.State(error: error)))
                    return .none

                case .path:
                    return .none

                case .whatsTheIssueAction:
                    return .none
                }
            }
            .forEach(\.path, action: \.path)
        }
    }

    public struct ReportBugView: View {
        @Perception.Bindable var store: StoreOf<ReportBugFeatureMacOS>

        public var body: some View {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                WhatsTheIssueView(
                    store: store.scope(
                        state: \.whatsTheIssueState,
                        action: \.whatsTheIssueAction
                    )
                )
            } destination: { store in
                switch store.case {
                case let .quickFixes(store):
                    QuickFixesView(store: store)
                case let .contactUs(store):
                    ContactFormView(store: store)
                case let .result(store):
                    BugReportResultView(store: store)
                }
            }
        }
    }

    #Preview {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let state = ReportBugFeatureMacOS.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeatureMacOS()

        return ReportBugView(store: Store(initialState: state, reducer: { reducer }))
            .frame(width: 600, height: 600)
    }

#endif
