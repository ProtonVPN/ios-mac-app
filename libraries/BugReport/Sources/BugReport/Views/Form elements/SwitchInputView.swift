//
//  Created on 2022-01-11.
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
import Strings

/// Toggle input styled for usage in bug report form.
struct SwitchInputView: View {
    var field: InputField
    @Binding var value: Bool
    @Environment(\.colors) var colors: Colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(field.label, isOn: $value)
                    .accessibilityIdentifier("Toggle \(field.submitLabel)")
                    .toggleStyle(SwitchToggleStyle(tint: colors.interactive))
            }
            .padding()
            #if os(iOS)
            .background(Rectangle().foregroundColor(colors.backgroundWeak))
            #endif

            if let placeholder = field.placeholder {
                Text(placeholder)
                    .font(.footnote)
                    .foregroundColor(colors.textSecondary)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview

struct SwitchInputView_Previews: PreviewProvider {
    @State private static var text: Bool = true

    static var previews: some View {
        SwitchInputView(
            field: InputField(label: Localizable.br3LogsField,
                              submitLabel: "logs",
                              type: .switch,
                              isMandatory: false,
                              placeholder: Localizable.br3LogsDescription),
            value: $text
        )
        .preferredColorScheme(.dark)
    }
}
