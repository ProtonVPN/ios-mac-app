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
import AppKit
import ProtonCore_UIFoundations
import vpncore

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
        static let cornerRadius: CGFloat = 8
    }

    public enum IconSize {
        case `default`
        case square(Int)
        case rect(width: Int, height: Int)

        static let profileIconSize: Self = .square(18)
    }

    public enum FlagStyle: String {
        case plain
        case large

        func imageName(countryCode: String) -> String {
            countryCode.lowercased() + "-\(self.rawValue)"
        }
    }

    @dynamicMemberLookup
    public enum Icon {
        static subscript(dynamicMember keyPath: KeyPath<IconProviderBase, NSImage>) -> NSImage {
            return IconProvider[keyPath: keyPath]
        }

        static func flag(countryCode: String, style: FlagStyle = .plain) -> NSImage? {
            if style == .plain {
                return IconProvider.flag(forCountryCode: countryCode)
            }
            return NSImage(named: style.imageName(countryCode: countryCode))
        }

        #if STAGING // use Debug icon for staging builds
        static let appIconConnected = Asset.dynamicAppIconDebugConnected.image
        static let appIconDisconnected = Asset.dynamicAppIconDebugDisconnected.image
        #else
        static let appIconConnected = Asset.dynamicAppIconConnected.image
        static let appIconDisconnected = Asset.dynamicAppIconDisconnected.image
        #endif

        static let vpnConnected = Asset.connected.image
        static let vpnNotConnected = Asset.disconnected.image
        static let vpnConnecting = Asset.idle.image
        static let vpnEmpty = Asset.emptyIcon.image

        static let vpnResultConnected = Asset.vpnResultConnected.image
        static let vpnResultDisconnected = Asset.vpnResultNotConnected.image
        static let vpnResultTimeout = Asset.vpnResultWarning.image

        static let vpnWordmarkAlwaysDark = Asset.vpnWordmarkAlwaysDark.image
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
