//
//  Created on 03/06/2022.
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

import ProtonCoreUIFoundations
import SwiftUI

/// Country flags already read from the catalogue, including the codes that have no flag.
///
/// Flags come from the same catalogue as the icons and cost the same 38 microseconds per read, and a
/// country list asks for one per row, so they are read once per country code.
private let flagImages = ThemeAssetCache<String, ImageAsset.Image?>()

public extension ImageAsset.Image {
    /// The flag of the country, or `nil` when the catalogue has no flag for that code.
    static func flag(countryCode: String) -> ImageAsset.Image? {
        flagImages.value(for: countryCode) { code in
            IconProvider.flag(forCountryCode: code)
        }
    }
}

#if os(macOS)
    public extension ImageAsset.Image {
        var swiftUIImage: SwiftUI.Image {
            SwiftUI.Image(nsImage: self)
        }
    }
#else
    public extension ImageAsset.Image {
        var swiftUIImage: SwiftUI.Image {
            SwiftUI.Image(uiImage: self)
        }
    }
#endif
