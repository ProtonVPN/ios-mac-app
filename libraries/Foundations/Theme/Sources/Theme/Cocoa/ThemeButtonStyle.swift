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

#if canImport(AppKit)

    import SwiftUI

    public struct ThemeButtonStyle: ButtonStyle {
        let padding: Padding
        let style: Style

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
                    .themeSpacing12
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

        public init(padding: Padding = .medium, style: Style = .primary) {
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

        public func makeBody(configuration: Self.Configuration) -> some View {
            configuration
                .label
                .foregroundColor(Color(.text, isEnabled ? [] : [.hint]))
                .font(.body(emphasised: true))
                .padding(.vertical, padding.vertical)
                .padding(.horizontal, padding.horizontal)
                .background(backgroundColor(isPressed: configuration.isPressed))
                .cornerRadius(.themeRadius8)
                .onHover { isHovered = $0 }
                .linkPointer()
        }
    }

    public extension View {
        func linkPointer() -> some View {
            if #available(macOS 15.0, *) {
                return self.pointerStyle(.link)
            } else {
                return self
            }
        }
    }
#endif
