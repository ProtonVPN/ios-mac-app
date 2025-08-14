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

#if os(iOS)
    import ComposableArchitecture
    import Foundation
    import SwiftUI

    public struct ReportBugView: View {
        @Perception.Bindable var store: StoreOf<ReportBugFeature>

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
        bugReport.sendCallback = { _, result in
            result(.success(()))
        }

        let state = ReportBugFeature.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeature()

        return ReportBugView(store: Store(initialState: state, reducer: { reducer }))
    }

#endif
