//
//  Created on 14/04/2023.
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

import ProtonCoreUIFoundations
import Theme
import Cocoa
#if canImport(SwiftUI)
import SwiftUI
#endif

extension AppTheme {
    @dynamicMemberLookup
    public enum Icon {
        static subscript(dynamicMember keyPath: KeyPath<IconProviderBase, NSImage>) -> NSImage {
            return IconProvider[keyPath: keyPath]
        }

        static func flag(countryCode: String, style: AppTheme.FlagStyle = .plain) -> NSImage? {
            if style == .plain {
                return IconProvider.flag(forCountryCode: countryCode)
            }
            return NSImage(named: style.imageName(countryCode: countryCode))
        }

#if canImport(SwiftUI)
        static func flag(countryCode: String, style: AppTheme.FlagStyle = .plain) -> Image? {
            if style == .plain {
                return IconProvider.flag(forCountryCode: countryCode)
            }
            return Image(style.imageName(countryCode: countryCode))
        }
#endif
    }
}
