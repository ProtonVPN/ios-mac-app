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

struct LinkButtonStyle: ButtonStyle {

    @State var isHovered = false

    func helpForegroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.interactive, .hint]
        if isHovered {
            style = [.interactive, .hint, .hovered]
        }
        if isPressed {
            style = [.interactive, .hint, .active]
        }
        return .init(NSColor.color(.text, style))
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(helpForegroundColor(isPressed: configuration.isPressed))
            .onHover { isHovered = $0 }
    }
}
