//
//  Created on 08/03/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Theme

struct ThemeButtonStyle: ButtonStyle {

    let padding: Padding
    let style: Style

    @State private var isHovered = false
    @Environment(\.isEnabled) var isEnabled

    enum Style {
        case primary
        case secondary
    }

    enum Padding {
        case small
        case medium

        var vertical: CGFloat {
            switch self {
            case .small:
                return .themeSpacing8
            case .medium:
                return .themeSpacing12
            }
        }

        var horizontal: CGFloat {
            switch self {
            case .small:
                return .themeSpacing16
            case .medium:
                return .themeSpacing24
            }
        }
    }

    init(padding: Padding = .medium, style: Style = .primary) {
        self.padding = padding
        self.style = style
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var backgroundStyle: AppTheme.Style = [.interactive]
        if style == .secondary {
            backgroundStyle.insert(.weak)
        }
        if isPressed {
            backgroundStyle.insert(.active)
        }
        if isHovered {
            backgroundStyle.insert(.hovered)
        }
        return Color(.background, backgroundStyle)
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, isEnabled ? [] : [.hint]))
            .font(.body(emphasised: true))
            .padding(.vertical, padding.vertical)
            .padding(.horizontal, padding.horizontal)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .onHover { isHovered = $0 }
    }
}
