//
//  Created on 2022-01-05.
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

import SwiftUI

/// Single line text input styled for usage in bug report form.
@available(iOS 14.0, macOS 11, *)
struct SingleLineTextInputView: View {
    var field: InputField
    @Binding var value: String
    @Environment(\.colors) var colors: Colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(field.label)
                .font(.system(size: 13))
                .padding(.bottom, 8)

            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text(field.placeholder ?? "")
                        .lineLimit(1)
                        .foregroundColor(colors.textSecondary)
                }

                TextField("", text: $value)
                    .accessibilityIdentifier("Single line input \(field.submitLabel)")
                    .textFieldStyle(.plain)
                    .foregroundColor(colors.textPrimary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal)
            .background(RoundedRectangle(cornerRadius: 8).foregroundColor(colors.backgroundSecondary))

        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

@available(iOS 14.0, macOS 11, *)
struct SingleLineTextInputView_Previews: PreviewProvider {
    @State private static var text: String = ""

    static var previews: some View {
        SingleLineTextInputView(
            field: InputField(
                label: "Email",
                submitLabel: "",
                type: .textSingleLine,
                isMandatory: true,
                placeholder: "User name (email address)"),
            value: $text)

            .preferredColorScheme(.dark)
    }
}
