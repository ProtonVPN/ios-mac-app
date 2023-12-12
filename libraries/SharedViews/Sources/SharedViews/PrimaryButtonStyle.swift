//
//  Created on 21/08/2023.
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

public struct SecondaryButtonStyle: ButtonStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, .interactive))
#if canImport(UIKit)
            .frame(maxWidth: .infinity, minHeight: .themeSpacing32)
            .font(.body1())
#endif
            .padding(.vertical, .themeSpacing8)
        //            .background(backgroundColor(isPressed: configuration.isPressed))
            .themeBorder(color: .black,
                         lineWidth: 0,
                         cornerRadius: .radius8)
    }
}

public struct PrimaryButtonStyle: ButtonStyle {

    @State var isHovered = false

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, .primary))
#if canImport(UIKit)
            .frame(maxWidth: .infinity, minHeight: .themeSpacing32)
            .font(.body1())
#elseif canImport(Cocoa)
            .padding(.horizontal, .themeSpacing24)
            .padding(.vertical, .themeSpacing6)
            .font(.body(emphasised: true))
#endif
            .padding(.vertical, .themeSpacing8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .themeBorder(color: .black,
                         lineWidth: 0,
                         cornerRadius: .radius8)
            .onHover {
                isHovered = $0
#if canImport(Cocoa)
                if ($0) {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
#endif
            }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = [.interactive]
#if canImport(Cocoa)
        if isPressed {
            style.insert(.active)
        } else if isHovered {
            style.insert(.hovered)
        }
#endif
        return Color(.background, style)
    }
}

struct PrimaryButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        Button {

        } label: {
            Text("Preview button")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}
