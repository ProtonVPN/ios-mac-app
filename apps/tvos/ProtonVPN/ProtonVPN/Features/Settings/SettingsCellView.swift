//
//  Created on 08/05/2024.
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

struct SettingsCellView: View {

    let title: String
    let icon: Image
    let action: () -> Void

    @FocusState var focusState: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: .themeSpacing32) {
                icon
                    .resizable()
                    .frame(.square(48))
                Text(title)
                    .font(.callout)
                Spacer()
            }
        }
        .focused($focusState, equals: true)
        .buttonStyle(SettingsButtonStyle())
    }
}

struct SettingsButtonStyle: ButtonStyle {

    private static let size = CGSize(width: 800, height: 120)

    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.leading, .themeSpacing48)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(isFocused ? Color(.background, .hovered) : Color(.background))
            .foregroundStyle(isFocused ? Color(.text, .inverted) : Color(.text))
            .cornerRadius(.themeRadius24)
            .hoverEffect(.highlight)
    }
}
