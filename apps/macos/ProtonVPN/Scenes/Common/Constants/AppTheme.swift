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

    public struct Style: OptionSet {
        public let rawValue: Int

        // Modifiers
        public static let normal = Self(bitPosition: 0)
        public static let `weak` = Self(bitPosition: 1)
        public static let `strong` = Self(bitPosition: 2)
        public static let inverted = Self(bitPosition: 3)
        public static let disabled = Self(bitPosition: 4)
        public static let transparent = Self(bitPosition: 5)

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

    public enum IconSize {
        case `default`
        case square(Int)
        case rect(width: Int, height: Int)
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
            return NSImage(named: style.imageName(countryCode: countryCode))
        }

        static let vpnConnected = NSImage(named: "vpn-connected")!
        static let vpnNotConnected = NSImage(named: "vpn-not-connected")!
        static let vpnConnecting = NSImage(named: "vpn-connecting")!
        static let vpnEmpty = NSImage(named: "vpn-empty")!
    }
}

public protocol CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style
}
