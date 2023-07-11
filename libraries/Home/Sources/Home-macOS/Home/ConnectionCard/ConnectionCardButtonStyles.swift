//
//  Created on 10/07/2023.
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

struct ConnectButtonStyle: ButtonStyle {

    @State var isHovered = false
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .font(.body(emphasised: true))
            .foregroundColor(Color(.text, .primary))
            .padding(.vertical, .themeSpacing8)
            .padding(.horizontal, .themeSpacing16)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .onHover { isHovered = $0 }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.interactive]
        style.insert(isHovered ? .hovered : [])
        style.insert(isActive ? [] : .weak)
        return Color(.background, style)
    }
}

struct ShowConnectionDetailsButtonStyle: ButtonStyle {

    @State var isHovered = false
    @State var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text))
            .padding(.themeSpacing8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .onHover { isHovered = $0 }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = []
        style.insert(isHovered && enabled ? .hovered : [.transparent])
        return Color(.background, style)
    }
}

struct HelpButtonStyle: ButtonStyle {

    @State var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, isHovered ? [] : .weak))
            .font(.callout(emphasised: false))
            .padding(.themeSpacing4)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .onHover { isHovered = $0 }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.transparent]
        style.insert(isHovered ? .hovered : [])
        return Color(.background, style)
    }
}
