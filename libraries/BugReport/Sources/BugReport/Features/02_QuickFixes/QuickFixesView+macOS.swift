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
    import Strings
    import SwiftUI

    struct QuickFixesView: View {
        let store: StoreOf<QuickFixesFeature>

        @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel

        let assetsBundle = CurrentEnv.assetsBundle
        @Environment(\.colors) var colors: Colors
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            WithPerceptionTracking {
                ZStack {
                    colors.background.ignoresSafeArea()

                    VStack(alignment: .center) {
                        StepProgress(step: 2, steps: 3, colorMain: colors.interactive, colorText: colors.textAccent, colorSecondary: colors.interactiveActive)
                            .padding(.bottom)

                        UpdateAvailableView(isActive: $updateViewModel.updateIsAvailable)

                        VStack(alignment: .center, spacing: 8) {
                            Text(Localizable.br2Title)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(Localizable.br2Subtitle)
                                .font(.subheadline)
                        }
                        .padding(.horizontal)

                        VStack {
                            if let suggestions = store.category.suggestions {
                                ForEach(suggestions) { suggestion in
                                    VStack(alignment: .leading) {
                                        if let link = suggestion.link, let url = URL(string: link) {
                                            Link(destination: url) {
                                                HStack(alignment: .top) {
                                                    Image(Asset.icLightbulb.name, bundle: assetsBundle)
                                                        .renderingMode(.template)
                                                        .foregroundColor(colors.qfIcon)
                                                    Text(suggestion.text)
                                                        .lineSpacing(7)
                                                        .multilineTextAlignment(.leading)
                                                        .frame(minHeight: 24, alignment: .leading)
                                                    Spacer()
                                                    Image(Asset.icArrowOutSquare.name, bundle: assetsBundle)
                                                        .renderingMode(.template)
                                                        .foregroundColor(colors.externalLinkIcon)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .onHover { inside in
                                                if inside {
                                                    NSCursor.pointingHand.push()
                                                } else {
                                                    NSCursor.pop()
                                                }
                                            }
                                        } else {
                                            HStack(alignment: .top) {
                                                Image(Asset.icLightbulb.name, bundle: assetsBundle)
                                                    .renderingMode(.template)
                                                    .foregroundColor(colors.qfIcon)
                                                Text(suggestion.text)
                                                    .lineSpacing(7)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(minHeight: 24, alignment: .leading)
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                        }
                                        Divider().hidden()
                                    }
                                }
                            }
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 16)

                        Text(Localizable.br2Footer)
                            .foregroundColor(colors.textSecondary)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 32)

                        NavigationLink(
                            state: ReportBugFeatureMacOS.Path.State
                                .contactUs(
                                    ContactFormFeature
                                        .State(fields: store.category.inputFields, category: store.category.label)
                                ),
                            label: {
                                Text(Localizable.br2ButtonNext)
                                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
                                    .padding(.horizontal, 16)
                                    .background(colors.interactive)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        )
                    }
                    .foregroundColor(colors.textPrimary)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: {
                                dismiss()
                            }, label: {
                                Image(systemName: "chevron.left").foregroundColor(colors.textPrimary)
                            })
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview

    #Preview {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport

        return QuickFixesView(store: Store(initialState: QuickFixesFeature.State(category: bugReport.model.categories[0]), reducer: { QuickFixesFeature() })
        )
    }

#endif
