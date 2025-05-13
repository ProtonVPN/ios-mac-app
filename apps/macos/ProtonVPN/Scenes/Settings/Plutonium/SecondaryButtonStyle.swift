//
//  Created on 2025-05-07 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI

import Theme

struct SecondaryButtonStyle: ButtonStyle {

    @State var isHovered: Bool = false
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .font(.body(emphasised: true))
            .foregroundColor(Color(.text, isEnabled ? [] : [.hint]))
            .padding(.vertical, .themeSpacing8)
            .padding(.horizontal, .themeSpacing16)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .onHover { isHovered = $0 }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.interactive, .weak]
        if isPressed {
            style.insert(.active)
        } else if isHovered {
            style.insert(.hovered)
        }
        return Color(.background, style)
    }
}
