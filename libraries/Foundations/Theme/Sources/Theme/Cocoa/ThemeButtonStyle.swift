//
//  Created on 2025-08-29 by Pawel Jurczyk.
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

public struct ThemeButtonStyle: ButtonStyle {
    let padding: Padding
    let style: Style
    let maxWidth: CGFloat?

    @State private var isHovered = false
    @Environment(\.isEnabled) var isEnabled

    public enum Style {
        case primary
        case secondary
    }

    public enum Padding {
        case small
        case medium

        var vertical: CGFloat {
            switch self {
            case .small:
                .themeSpacing8
            case .medium:
                #if canImport(AppKit)
                    .themeSpacing12
                #else
                    .themeSpacing16
                #endif
            }
        }

        var horizontal: CGFloat {
            switch self {
            case .small:
                .themeSpacing16
            case .medium:
                .themeSpacing24
            }
        }
    }

    public init(padding: Padding = .medium, style: Style = .primary, maxWidth: CGFloat? = nil) {
        self.padding = padding
        self.style = style
        #if canImport(UIKit)
            self.maxWidth = maxWidth ?? .infinity
        #else
            self.maxWidth = maxWidth
        #endif
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var backgroundStyle: AppTheme.Style = [.interactive]
        if style == .secondary {
            backgroundStyle.insert(.weak)
        }
        if !isEnabled {
            backgroundStyle.insert([.weak, .disabled])
        }
        if isPressed {
            backgroundStyle.insert(.active)
        }
        if isHovered {
            backgroundStyle.insert(.hovered)
        }
        return Color(.background, backgroundStyle)
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration
            .label
        #if canImport(AppKit)
            .font(.body(emphasised: true))
            .onHover { isHovered = $0 }
        #else
            .font(.body1(.semibold))
        #endif
            .frame(maxWidth: maxWidth)
            .foregroundColor(Color(.text, isEnabled ? [.primary] : [.weak]))
            .padding(.vertical, padding.vertical)
            .padding(.horizontal, padding.horizontal)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .linkPointer()
    }
}

public extension View {
    func linkPointer() -> some View {
        #if canImport(AppKit)
            if #available(macOS 15.0, *) {
                return pointerStyle(.link)
            } else {
                return self
            }
        #else
            return self
        #endif
    }
}

extension SwiftUICore.ColorScheme: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .light:
            "Light"
        case .dark:
            "Dark"
        @unknown default:
            "Unknown"
        }
    }
}

#Preview {
    HStack {
        ForEach([SwiftUICore.ColorScheme.dark, .light], id: \.hashValue) { scheme in
            VStack {
                Text("\(scheme.description) scheme")
                HStack {
                    Text("padding")
                    Text("style")
                    Text("enabled?")
                }
                Button("Small, secondary, enabled") {}
                    .buttonStyle(ThemeButtonStyle(
                        padding: .small,
                        style: .secondary
                    ))
                Button("Medium, secondary, enabled") {}
                    .buttonStyle(ThemeButtonStyle(
                        padding: .medium,
                        style: .secondary
                    ))
                Button("Small, PRIMARY, enabled") {}
                    .buttonStyle(ThemeButtonStyle(
                        padding: .small,
                        style: .primary
                    ))
                Button("Medium, PRIMARY, enabled") {}
                    .buttonStyle(ThemeButtonStyle(
                        padding: .medium,
                        style: .primary
                    ))
                Button("Medium, PRIMARY, disabled") {}
                    .buttonStyle(ThemeButtonStyle(
                        padding: .medium,
                        style: .primary
                    ))
                    .disabled(true)
            }
            .padding()
            .background(Color(.background, .weak))
            .colorScheme(scheme)
        }
    }
}
