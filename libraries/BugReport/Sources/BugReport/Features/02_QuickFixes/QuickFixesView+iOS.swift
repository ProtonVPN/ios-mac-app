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

    public struct QuickFixesView: View {
        @Perception.Bindable var store: StoreOf<QuickFixesFeature>

        @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

        let assetsBundle = CurrentEnv.assetsBundle
        @Environment(\.colors) var colors: Colors
        @Environment(\.dismiss) private var dismiss

        public var body: some View {
            WithPerceptionTracking {
                ZStack {
                    colors.background.ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 0) {
                        StepProgress(step: 2, steps: 3, colorMain: colors.interactive, colorText: colors.textAccent, colorSecondary: colors.interactiveActive)
                            .padding(.bottom)

                        UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localizable.br2Title)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(Localizable.br2Subtitle)
                                .font(.subheadline)
                                .foregroundColor(colors.textSecondary)
                        }.padding(.horizontal)

                        VStack {
                            if let suggestions = store.category.suggestions {
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

                        Text(Localizable.br2Footer)
                            .foregroundColor(colors.textSecondary)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Spacer()

                        VStack {
                            NavigationLink(
                                state: ReportBugFeature.Path.State.contactUs(ContactFormFeature.State(fields: store.category.inputFields, category: store.category.label)),
                                label: {
                                    Text(Localizable.br2ButtonNext)
                                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
                                        .padding(.horizontal, 16)
                                        .background(colors.interactive)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            )

                            Button(
                                action: { dismiss() },
                                label: { Text(Localizable.br2ButtonCancel) }
                            )
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                    .foregroundColor(colors.textPrimary)
                    // Custom Back button
                    .navigationBarBackButtonHidden(true)
                    .navigationBarItems(leading: Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "chevron.left").foregroundColor(colors.textPrimary)
                    }))
                }
            }
        }
    }

    // MARK: - Preview

    #Preview {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        return Group {
            QuickFixesView(store: Store(
                initialState: QuickFixesFeature.State(category: bugReport.model.categories[0]),
                reducer: { QuickFixesFeature() }
            )
            )
        }
    }

#endif
