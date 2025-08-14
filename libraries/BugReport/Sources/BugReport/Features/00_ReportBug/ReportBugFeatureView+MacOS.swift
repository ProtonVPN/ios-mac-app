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

    public struct ReportBugView: View {
        @Perception.Bindable var store: StoreOf<ReportBugFeature>

        @Environment(\.colors) var colors: Colors
        @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

        public var body: some View {
            WithPerceptionTracking {
                ZStack {
                    colors.background.ignoresSafeArea()

                    VStack(alignment: .center) {
                        if !store.path.contains(where: { pathState in
                            if case .result = pathState {
                                return true
                            }
                            return false
                        }) {
                            StepProgress(
                                step: UInt(store.path.count + 1),
                                steps: 3,
                                colorMain: colors.primary,
                                colorText: colors.textAccent,
                                colorSecondary: colors.backgroundStrong ?? colors.backgroundWeak
                            )
                            .transition(.opacity)

                            UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)
                        }

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
                        .animation(.easeInOut(duration: 0.3), value: store.path.count)
                    }
                }
            }
        }
    }

    #Preview {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let state = ReportBugFeature.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeature()

        return ReportBugView(store: Store(initialState: state, reducer: { reducer }))
            .frame(width: 600, height: 600)
    }

#endif
