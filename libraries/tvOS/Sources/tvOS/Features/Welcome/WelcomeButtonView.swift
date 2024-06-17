//
//  Created on 22/05/2024.
//
//  Copyright (c) 2024 Proton AG
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

struct WelcomeButtonView: View {

    let title: LocalizedStringKey
    let action: () -> Void

    @FocusState var focusState: Bool

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.bold)
        }
        .focused($focusState, equals: true)
        .buttonStyle(WelcomeButtonStyle())
    }
}

private struct WelcomeButtonStyle: ButtonStyle {

    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, .themeSpacing32)
            .padding(.vertical, .themeSpacing24)
            .background(isFocused ? Color(.background, .hovered) : Color(.background, .weak))
            .foregroundStyle(isFocused ? Color(.text, .inverted) : Color(.text))
            .cornerRadius(.themeRadius16)
            .hoverEffect(.highlight)
    }
}
