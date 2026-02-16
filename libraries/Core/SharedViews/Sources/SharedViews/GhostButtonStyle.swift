//
//  Created on 2025-05-08 by Pawel Jurczyk.
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

public struct GhostButtonStyle: ButtonStyle {
    @State var isHovered: Bool = false
    @Environment(\.isEnabled) var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .font(.callout(emphasised: true))
            .foregroundColor(Color(.text, isEnabled ? [] : [.hint]))
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .linkPointer()
            .onHover { isHovered = $0 }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.transparent]
        if isPressed {
            style.insert(.active)
        } else if isHovered {
            style.insert(.hovered)
        } else {
            return .clear
        }
        return Color(.background, style)
    }
}

public extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle {
        GhostButtonStyle()
    }
}
