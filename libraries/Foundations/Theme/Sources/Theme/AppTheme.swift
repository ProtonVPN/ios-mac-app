//
//  Created on 2022-03-10.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import Ergonomics
import SwiftUI

public enum ColorScheme {
    case light
    case dark
    case auto
}

public enum AppTheme {
    public enum Context: String {
        case background
        case border
        case field
        case text
        case icon
    }

    public struct Style: OptionSet, Hashable {
        public let rawValue: Int

        // Modifiers
        public static let normal = Self(bitPosition: 0)
        public static let hint = Self(bitPosition: 1)
        public static let `weak` = Self(bitPosition: 2)
        public static let `strong` = Self(bitPosition: 3)
        public static let inverted = Self(bitPosition: 4)
        public static let disabled = Self(bitPosition: 5)
        public static let transparent = Self(bitPosition: 6)
        /// Static color, not changing together with appearance change. For text it's always white
        public static let primary = Self(bitPosition: 7)
        public static let dropdown = Self(bitPosition: 8)
        public static let vpnGreen = Self(bitPosition: 9)

        // Action contexts
        public static let interactive = Self(bitPosition: 10)
        public static let success = Self(bitPosition: 11)
        public static let cancel = Self(bitPosition: 12)
        public static let danger = Self(bitPosition: 13)
        public static let warning = Self(bitPosition: 14)
        public static let active = Self(bitPosition: 15)
        public static let hovered = Self(bitPosition: 16)
        public static let info = Self(bitPosition: 17)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public enum MacAppLayout: CGFloat {
        case mainContainerMinWidth = 360
        case mainContainerMinHeight = 480

        case rightSidebarWidth = 260
        case leftSidebarWidth = 160

        case connectionCardMaxWidth = 620
        public static let connectionCardMinWidth = Self.mainContainerMinWidth

        case mainAppDefaultHeight = 580
        public static let mainAppDefaultWidth = Self.connectionCardMaxWidth
    }

    public enum CornerRadius: CGFloat {
        case radius2 = 2
        case radius2½ = 2.5
        case radius4 = 4
        case radius7 = 7
        case radius8 = 8
        case radius12 = 12
        case radius16 = 16
        case radius24 = 24
        case radius32 = 32
        case radius36 = 36
    }

    public enum Spacing: CGFloat {
        case spacing2 = 2
        case spacing4 = 4
        case spacing6 = 6
        case spacing8 = 8
        case spacing12 = 12
        case spacing16 = 16
        case spacing24 = 24
        case spacing32 = 32
        case spacing48 = 48
        case spacing64 = 64
        case spacing120 = 120
    }

    public enum FontSize: Double {
        case title = 48

        case heading1 = 36
        case heading2 = 20
        case heading3 = 18
        case heading4 = 16

        case paragraph = 14
        case small = 12
        case tiny = 10
    }

    /// Constant button values, in pixels.
    public enum ButtonConstants {
        /// The standard radius of a button throughout the app.
        public static let cornerRadius: CGFloat = 8
    }

    public enum IconSize {
        case `default`
        case square(CGFloat)
        case rect(width: CGFloat, height: CGFloat)

        public static let profileIconSize: Self = .square(18)
        public static let flagIconSize: Self = .rect(width: 32, height: 21.33)
        public static let secureCoreFlagIconSize: Self = .rect(width: 18, height: 12)

        var width: CGFloat? {
            switch self {
            case .default:
                return nil
            case let .square(width):
                return width
            case let .rect(width, _):
                return width
            }
        }

        var height: CGFloat? {
            switch self {
            case .default:
                return nil
            case let .square(width):
                return width
            case let .rect(_, height):
                return height
            }
        }
    }

    public enum FlagStyle: String {
        case plain
        case large

        public func imageName(countryCode: String) -> String {
            countryCode.lowercased() + "-\(self.rawValue)"
        }
    }
}

public protocol CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style
}

extension AppTheme.Style: CustomDebugStringConvertible {
    public var debugDescription: String {
        // "normal" is the empty set (0)
        guard self != .normal else {
            return "normal"
        }

        var copy = self
        let lookup: [AppTheme.Style: String] = [
            .weak: "weak",
            .transparent: "transparent",
            .hovered: "hovered",
            .strong: "strong",
            .active: "active",
            .hint: "hint",
            .disabled: "disabled",
            .cancel: "cancel",
            .danger: "danger",
            .info: "info",
            .interactive: "interactive",
            .inverted: "inverted",
            .warning: "warning",
        ]

        var result = ""
        for (item, name) in lookup {
            if copy.contains(item) {
                if !result.isEmpty {
                    result += ", "
                }
                result += name
                copy.remove(item)
            }
        }

        assert(copy.isEmpty, "Style item missing from debug description")
        return result
    }
}
