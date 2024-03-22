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
import Foundation
import ComposableArchitecture
import SwiftUI
import Strings

struct QuickFixesView: View {
    let store: StoreOf<QuickFixesFeature>

    let assetsBundle = CurrentEnv.assetsBundle
    @Environment(\.colors) var colors: Colors

    var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in
        VStack(alignment: .center) {

            VStack(alignment: .center, spacing: 8) {
                Text(Localizable.br2Title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(Localizable.br2Subtitle)
                    .font(.subheadline)
            }
            .padding(.horizontal)

            VStack {
                    if let suggestions = viewStore.category.suggestions {
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
                                        .frame(width: 310) // Magic number that that prevents button to be too wide. Should be changed in case we change the width of ReportBug window.
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
                                Divider().hidden() // Makes view fill whole width
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

            Button(action: {
                viewStore.send(.next, animation: .default)
            }, label: {
                Text(Localizable.br2ButtonNext)
            })
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
        }
        .foregroundColor(colors.textPrimary)
        .background(colors.background)
        })
    }
}

// MARK: - Preview

struct QuickFixesView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport

        return Group {
            QuickFixesView(store: Store(initialState: QuickFixesFeature.State(category: bugReport.model.categories[0]), reducer: { QuickFixesFeature() })
            )
        }
    }
}

#endif
