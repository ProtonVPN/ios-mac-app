//
//  Created on 2021-12-20.
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

/// First step of Bug Report flow.
/// Asks user to define problem category.
@available(iOS 14.0, *)
public struct BugReportView: View {
        
    private var delegate: BugReportDelegate = Current.bugReportDelegate
    @Environment(\.colors) var colors: Colors
        
    public var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                StepProgress(step: 1, steps: 3, colorMain: colors.brand, colorSecondary: colors.brandLight40)
                    .padding(.bottom)
                
                Text(LocalizedString.br1Title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)
                    .padding(.horizontal)
                
                List(delegate.model.categories) { category in
                    if category.suggestions?.isEmpty ?? true { // If no suggestions found skip directly to the form
                        NavigationLink(destination: {
                            FormView(viewModel: FormViewModel(fields: category.inputFields))
                                .navigationTitle(Text(LocalizedString.brWindowTitle))
                        }) { Text(category.label) }
                        
                    } else {
                        NavigationLink(destination: {
                            QuickFixesList(category: category)
                                .navigationTitle(Text(LocalizedString.brWindowTitle))
                        }) { Text(category.label) }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(Text(LocalizedString.brWindowTitle))
            .navigationBarTitleDisplayMode(.inline)
            
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
    
    public init(){ }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct BugReportView_Previews: PreviewProvider {
    static var previews: some View {
        
        return Group {
            BugReportView()
                .previewDevice("iPhone 8")
        }
    }
}
