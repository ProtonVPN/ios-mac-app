//
//  Created on 2021-12-22.
//
//  Copyright (c) 2021 Proton AG
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

import SwiftUI

/// Second step of Report Bug flow.
/// Suggests quick fixes to user and allows to procede to contact form.
@available(iOS 14.0, *)
struct QuickFixesList: View {
    
    let category: Category
    
    let assetsBundle = Current.assetsBundle
    @Environment(\.colors) var colors: Colors
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack(alignment: .leading) {
            StepProgress(step: 2, steps: 3, colorMain: colors.brand, colorSecondary: colors.brandLight40)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.br2Title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(LocalizedString.br2Subtitle)
                    .font(.subheadline)
                    .foregroundColor(colors.textSecondary)
            }.padding(.horizontal)
            
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
                                            .multilineTextAlignment(.leading)
                                            .lineSpacing(7)
                                            .frame(minHeight: 24, alignment: .leading)
                                        Spacer()
                                        Image(Asset.quickfixLink.name, bundle: assetsBundle)
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                HStack(alignment: .top) {
                                    Image(Asset.lightbulb.name, bundle: assetsBundle)
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
                Button(action: {}) {
                    NavigationLink(destination: FormView(viewModel: FormViewModel(fields: category.inputFields)).navigationTitle(Text(LocalizedString.brWindowTitle))) {
                        Text(LocalizedString.br2ButtonNext)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
                            .padding(.horizontal, 16)
                            .background(colors.brand)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) { Text(LocalizedString.br2ButtonCancel) }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .foregroundColor(colors.textPrimary)
        // Custom Back button
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action : {
            self.presentationMode.wrappedValue.dismiss()
        }){
            Image(systemName: "arrow.left").foregroundColor(colors.textPrimary)
        })
        
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct QuickFixesList_Previews: PreviewProvider {
    static var previews: some View {
        let category = Category(label: "Browsing speed",
                                submitLabel: "Submit",
                                suggestions: [
                                    Suggestion(text: "Secure Core slows down your connection. Use it only when necessary.", link: nil),
                                    Suggestion(text: "Select a server closer to your location.", link: "https://protonvpn.com/faq/choosing_best_server"),
                                ],
                                inputFields: [])
        
        return QuickFixesList(category: category)
            .preferredColorScheme(.dark)
    }
}
