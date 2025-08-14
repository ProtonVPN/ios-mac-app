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
    import Strings
    import SwiftUI

    public struct WhatsTheIssueView: View {
        @Perception.Bindable var store: StoreOf<WhatsTheIssueFeature>
        @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel
        @Environment(\.colors) var colors: Colors

        public var body: some View {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    StepProgress(step: 1, steps: 3, colorMain: colors.interactive, colorText: colors.textAccent, colorSecondary: colors.interactiveActive)
                        .padding(.bottom)

                    UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)

                    Text(Localizable.br1Title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))

                    WithPerceptionTracking {
                        List(store.state.categories) { category in
                            Button(action: {
                                store.send(.categorySelected(category))
                            }, label: {
                                Text(category.label)
                            })
                            .listRowBackground(colors.background)
                        }
                        .listStyle(.plain)
                        .foregroundColor(colors.textPrimary)
                    }
                }
                .navigationTitle(Text(Localizable.brWindowTitle))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Preview

    #Preview {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        return Group {
            WhatsTheIssueView(store: Store(
                initialState: WhatsTheIssueFeature.State(categories: bugReport.model.categories),
                reducer: { WhatsTheIssueFeature() }
            )
            )
        }
    }

#endif
