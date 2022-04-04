//
//  Created on 2022-01-20.
//
//  Copyright (c) 2022 Proton AG
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
import SwiftUI

@available(iOS 14.0, macOS 11, *)
struct QuickFixesMacOSList: View {

    let category: Category
    let finished: () -> Void

    let assetsBundle = CurrentEnv.assetsBundle
    @Environment(\.colors) var colors: Colors
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack(alignment: .center) {

            VStack(alignment: .center, spacing: 8) {
                Text(LocalizedString.br2Title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(LocalizedString.br2Subtitle)
                    .font(.subheadline)
            }
            .padding(.horizontal)

            VStack {
                if let suggestions = category.suggestions {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading) {
                            if let link = suggestion.link, let url = URL(string: link) {
                                Link(destination: url) {
                                    HStack(alignment: .top) {
                                        Image(Asset.lightbulb.name, bundle: assetsBundle)
                                            .foregroundColor(colors.qfIcon)
                                        Text(suggestion.text)
                                            .lineSpacing(7)
                                            .multilineTextAlignment(.leading)
                                            .frame(minHeight: 24, alignment: .leading)
                                        Spacer()
                                        Image(Asset.quickfixLink.name, bundle: assetsBundle)
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
                                    Image(Asset.lightbulb.name, bundle: assetsBundle)
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

            Text(LocalizedString.br2Footer)
                .foregroundColor(colors.textSecondary)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 32)

            Button(action: finished, label: {
                Text(LocalizedString.br2ButtonNext)
            })
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
        }
        .foregroundColor(colors.textPrimary)
        .background(colors.background)
    }
}

// MARK: - Preview

@available(iOS 14.0, macOS 11, *)
struct QuickFixesMacOSList_Previews: PreviewProvider {
    static var previews: some View {
        let category = Category(label: "Browsing speed",
                                submitLabel: "Submit",
                                suggestions: [
                                    Suggestion(text: "Secure Core slows down your connection. Use it only when necessary. Select a server closer to your location", link: nil),
                                    Suggestion(text: "Select a server closer to your location. Select a server closer to your location", link: "https://protonvpn.com/faq/choosing_best_server"),
                                ],
                                inputFields: [])

        return QuickFixesMacOSList(category: category, finished: { })
            .frame(width: 400.0)
            .preferredColorScheme(.dark)
    }
}
#endif
