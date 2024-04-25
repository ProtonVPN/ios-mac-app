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
import Foundation
import SwiftUI
import ComposableArchitecture
import Strings

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
                        // NavigationLink inside the list
                        .background(nextView())
                    }
                }
                .navigationTitle(Text(Localizable.brWindowTitle))
                .navigationBarTitleDisplayMode(.inline)
            }
    }

    private func nextView() -> some View {
        NavigationLink(
            unwrapping: $store.route,
            onNavigate: { _ in
                print("navigate")
            },
            destination: { childStore in

                let childStore = store.route
                switch childStore {
                case .quickFixes:
                    QuickFixesView(store: store.scope(state: \.route?.quickFixes, action: \.route.quickFixes)!)

                case .contactForm(_):
                    ContactFormView(store: store.scope(state: \.route?.contactForm, action: \.route.contactForm)!)
                    
                case .none:
                    EmptyView()
                }
            },
            label: { EmptyView() }
        )
    }

}

// MARK: - Preview

struct WhatsTheIssueView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        return Group {
            WhatsTheIssueView(store: Store(initialState: WhatsTheIssueFeature.State(categories: bugReport.model.categories),
                                           reducer: { WhatsTheIssueFeature() }
                                          )
            )
        }
    }
}

#endif
