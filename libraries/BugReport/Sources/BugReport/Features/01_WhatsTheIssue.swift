//
//  Created on 2023-04-17.
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

struct WhatsTheIssueFeature: Reducer {

    struct State: Equatable {
        var categories: [Category]
        var category: Category?

        var quickFixesState: QuickFixesFeature.State?
        var contactFormState: ContactFormFeature.State?
    }

    enum Action: Equatable {
        case categorySelected(Category)

        case quickFixesAction(QuickFixesFeature.Action)
        case quickFixesDeselected

        case contactFormAction(ContactFormFeature.Action)
        case contactFormDeselected
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .categorySelected(let category):
                state.category = category

                if let suggestions = category.suggestions, !suggestions.isEmpty {
                    state.quickFixesState = QuickFixesFeature.State(category: category)
                } else {
                    state.contactFormState = ContactFormFeature.State(fields: category.inputFields, category: category.label)
                }

                return .none

            // 02. Quick fixes

            case .quickFixesDeselected:
                state.quickFixesState = nil
                return .none

            case .quickFixesAction:
                return .none

            // 03. Contact form

            case .contactFormAction:
                return .none

            case .contactFormDeselected:
                state.contactFormState = nil
                return .none

            }
        }
        .ifLet(\.quickFixesState, action: /Action.quickFixesAction) {
            QuickFixesFeature()
        }
        .ifLet(\.contactFormState, action: /Action.contactFormAction) {
            ContactFormFeature()
        }

    }

}

public struct WhatsTheIssueView: View {

    let store: StoreOf<WhatsTheIssueFeature>
    #if os(iOS)
    @StateObject var updateViewModel: IOSUpdateViewModel = CurrentEnv.iOSUpdateViewModel
    #endif
    @Environment(\.colors) var colors: Colors

    public var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {

                    StepProgress(step: 1, steps: 3, colorMain: colors.interactive, colorText: colors.textAccent, colorSecondary: colors.interactiveActive)
                        .padding(.bottom)
#if os(iOS)
                    UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)
#endif
                    Text(LocalizedString.br1Title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))

                    WithViewStore(self.store, observe: { $0 }, content: { viewStore in
                        List(viewStore.state.categories) { category in
                            Button(action: {
                                viewStore.send(.categorySelected(category))
                            }, label: {
                                Text(category.label)
                            })
                            .listRowBackground(colors.background)
                        }
                        .listStyle(.plain)
                        .foregroundColor(colors.textPrimary)
                        // NavigationLink inside the list 
                        .background(nextView(viewStore))
                    })
                }
                .navigationTitle(Text(LocalizedString.brWindowTitle))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func nextView(_ viewStore: ViewStore<WhatsTheIssueFeature.State, WhatsTheIssueFeature.Action>) -> some View {

        NavigationLink(unwrapping: viewStore.binding(get: \.quickFixesState,
                                                     send: WhatsTheIssueFeature.Action.quickFixesDeselected),
                       onNavigate: { _ in },
                       destination: { _ in destinationWhatsNext() },
                       label: { EmptyView() })

        NavigationLink(unwrapping: viewStore.binding(get: \.contactFormState,
                                                     send: WhatsTheIssueFeature.Action.contactFormDeselected),
                       onNavigate: { _ in },
                       destination: { _ in destinationForm() },
                       label: { EmptyView() })

    }

    @ViewBuilder private func destinationWhatsNext() -> some View {
        IfLetStore(self.store.scope(state: \.quickFixesState,
                                    action: { .quickFixesAction($0) }),
                   then: { store in QuickFixesView(store: store) })
    }

    @ViewBuilder private func destinationForm() -> some View {
        IfLetStore(self.store.scope(state: \.contactFormState,
                                    action: { .contactFormAction($0) }),
                   then: { store in ContactFormView(store: store) })
    }

}

// MARK: - Preview

struct WhatsTheIssueView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        #if os(iOS)
        CurrentEnv.iOSUpdateViewModel.updateIsAvailable = true
        #endif
        return Group {
            WhatsTheIssueView(store: Store(initialState: WhatsTheIssueFeature.State(categories: bugReport.model.categories),
                                           reducer: WhatsTheIssueFeature()
                                          )
            )
        }
    }
}
