//
//  Created on 2023-04-27.
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

struct QuickFixesFeature: Reducer {

    struct State: Equatable {
        var category: Category

        var contactFormState: ContactFormFeature.State?
    }

    enum Action: Equatable {
        case next

        case contactFormAction(ContactFormFeature.Action)
        case contactFormDeselected
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .next:
                state.contactFormState = ContactFormFeature.State(fields: state.category.inputFields, category: state.category.label)
                return .none

            // 03. Contact form

            case .contactFormDeselected:
                state.contactFormState = nil
                return .none

            case .contactFormAction:
                return .none
            }
        }
        .ifLet(\.contactFormState, action: /Action.contactFormAction) {
            ContactFormFeature()
        }
    }

}

public struct QuickFixesView: View {

    let store: StoreOf<QuickFixesFeature>

    #if os(iOS)
    @StateObject var updateViewModel: IOSUpdateViewModel = CurrentEnv.iOSUpdateViewModel
    #endif
    let assetsBundle = CurrentEnv.assetsBundle
    @Environment(\.colors) var colors: Colors
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {

                    StepProgress(step: 2, steps: 3, colorMain: colors.interactive, colorText: colors.textAccent, colorSecondary: colors.interactiveActive)
                        .padding(.bottom)

                    #if os(iOS)
                    UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)
                    #endif

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedString.br2Title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(LocalizedString.br2Subtitle)
                            .font(.subheadline)
                            .foregroundColor(colors.textSecondary)
                    }.padding(.horizontal)

                    VStack {

                        if let suggestions = viewStore.category.suggestions {
                            ForEach(suggestions) { suggestion in
                                VStack(alignment: .leading) {
                                    if let link = suggestion.link, let url = URL(string: link) {
                                        Link(destination: url) {
                                            HStack(alignment: .top) {
                                                Image(Asset.icLightbulb.name, bundle: assetsBundle)
                                                    .foregroundColor(colors.qfIcon)
                                                Text(suggestion.text)
                                                    .multilineTextAlignment(.leading)
                                                    .lineSpacing(7)
                                                    .frame(minHeight: 24, alignment: .leading)
                                                Spacer()
                                                Image(Asset.icArrowOutSquare.name, bundle: assetsBundle)
                                                    .foregroundColor(colors.externalLinkIcon)
                                            }
                                        }
                                        .padding(.horizontal)
                                    } else {
                                        HStack(alignment: .top) {
                                            Image(Asset.icLightbulb.name, bundle: assetsBundle)
                                                .foregroundColor(colors.qfIcon)
                                            Text(suggestion.text)
                                                .lineSpacing(7)
                                                .multilineTextAlignment(.leading)
                                                .frame(minHeight: 24, alignment: .leading)
                                        }
                                        .padding(.horizontal)
                                    }
                                    Divider().background(colors.separator)
                                }
                            }
                        }

                    }
                    .padding(.top, 36)
                    .padding(.bottom, 24)

                    Text(LocalizedString.br2Footer)
                        .foregroundColor(colors.textSecondary)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()

                    VStack {

                        NavigationLink(unwrapping: viewStore.binding(get: \.contactFormState,
                                                                     send: QuickFixesFeature.Action.contactFormDeselected),
                                       onNavigate: { active in
                                                        if active {
                                                            viewStore.send(.next)
                                                        }
                                                    },
                                       destination: { _ in
                            IfLetStore(self.store.scope(state: \.contactFormState,
                                                        action: { .contactFormAction($0) }),
                                       then: { store in ContactFormView(store: store) })
                            },
                                       label: {
                                Text(LocalizedString.br2ButtonNext)
                                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
                                    .padding(.horizontal, 16)
                                    .background(colors.interactive)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                        })

                        Button(action: { self.dismiss() },
                               label: { Text(LocalizedString.br2ButtonCancel) })
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .foregroundColor(colors.textPrimary)
#if os(iOS)
                // Custom Back button
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading: Button(action: {
                    self.dismiss()
                }, label: {
                    Image(systemName: "chevron.left").foregroundColor(colors.textPrimary)
                }))
#endif
            }
        })
    }

}

// MARK: - Preview

struct QuickFixesView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        #if os(iOS)
        CurrentEnv.iOSUpdateViewModel.updateIsAvailable = true
        #endif
        return Group {
            NavigationView {
                QuickFixesView(store: Store(initialState: QuickFixesFeature.State(category: bugReport.model.categories[0]),
                                            reducer: QuickFixesFeature()
                                           )
                )
            }
        }
    }
}
