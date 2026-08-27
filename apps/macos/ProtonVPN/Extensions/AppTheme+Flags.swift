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

import Cocoa
import SwiftUI
import Theme

public extension AppTheme {
    /// The flag of the country, or `nil` when there is no flag for that code.
    ///
    /// Plain flags come from Theme, which reads them from ProtonCore's catalogue and remembers them.
    /// The larger ones live in this app's own catalogue under `FlagsLarge`, so they are looked up by
    /// name in the main bundle, which AppKit caches.
    static func flag(countryCode: String, style: FlagStyle = .plain) -> NSImage? {
        guard style != .plain else {
            return NSImage.flag(countryCode: countryCode)
        }
        return NSImage(named: style.imageName(countryCode: countryCode))
    }

    /// The flag of the country as a SwiftUI image, or `nil` when there is no flag for that code.
    static func flag(countryCode: String, style: FlagStyle = .plain) -> Image? {
        guard style != .plain else {
            return NSImage.flag(countryCode: countryCode)?.swiftUIImage
        }
        return Image(style.imageName(countryCode: countryCode))
    }
}
