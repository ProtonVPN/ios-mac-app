//
//  Created on 2022-01-19.
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

/// First step of Bug Report flow.
/// Asks user to define problem category.
@available(macOS 11, *)
public struct BugReportMacOSView: View {

    var categories: [Category]
    var categorySelected: (Category) -> Void

    @Environment(\.colors) var colors: Colors

    public var body: some View {

            VStack(alignment: .center) {

                Text(LocalizedString.br1Title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(categories) { category in
                        Button(category.label, action: { self.categorySelected(category) })
                    }
                }
                .buttonStyle(CategoryButtonStyle())
                .listStyle(.plain)
                .padding(.top, 32)
            }
            .background(colors.background)
    }

    init(categories: [Category], categorySelected: @escaping (Category) -> Void) {
        self.categories = categories
        self.categorySelected = categorySelected
    }
}

// MARK: - Preview

@available(macOS 11, *)
struct BugReportView_Previews: PreviewProvider {
    static var previews: some View {

        return Group {
            BugReportMacOSView(categories: CurrentEnv.bugReportDelegate!.model.categories, categorySelected: { _ in })
                .frame(width: 400.0)
        }
        .preferredColorScheme(.dark)
    }
}

#endif
