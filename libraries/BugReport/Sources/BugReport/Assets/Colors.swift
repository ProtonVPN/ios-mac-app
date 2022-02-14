//
//  Created on 2022-01-04.
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
import SwiftUI

/// All the colors used through this module. Colors.testColors is for testing purposes only. Apps should provide their own set of colors.
@available(iOS 14.0, *)
public struct Colors {

    public init(brand: Color, brandLight20: Color, brandLight40: Color, brandDark40: Color, textPrimary: Color, textSecondary: Color, background: Color, backgroundSecondary: Color, backgroundUpdateButton: Color, separator: Color, qfIcon: Color) {
        self.brand = brand
        self.brandLight20 = brandLight20
        self.brandLight40 = brandLight40
        self.brandDark40 = brandDark40
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.backgroundUpdateButton = backgroundUpdateButton
        self.separator = separator
        self.qfIcon = qfIcon
    }

    public var brand: Color
    public var brandLight20: Color
    public var brandLight40: Color
    public var brandDark40: Color

    public var textPrimary: Color
    public var textSecondary: Color

    public var background: Color
    public var backgroundSecondary: Color
    public var backgroundUpdateButton: Color
    public var separator: Color

    public var qfIcon: Color

    /// Default color set for testing and previews
    public static let testColors = Colors(
        brand: Color("brand", bundle: Bundle.module),
        brandLight20: Color("brand-lighten20", bundle: Bundle.module),
        brandLight40: Color("brand-lighten40", bundle: Bundle.module),
        brandDark40: Color("brand-darken40", bundle: Bundle.module),
        textPrimary: Color.white,
        textSecondary: Color("text-weak", bundle: Bundle.module),
        background: Color("background-norm", bundle: Bundle.module),
        backgroundSecondary: Color("background-secondary", bundle: Bundle.module),
        backgroundUpdateButton: Color("interaction-weak", bundle: Bundle.module),
        separator: Color("separator", bundle: Bundle.module),
        qfIcon: Color("notification-warning", bundle: Bundle.module)
    )

}

@available(iOS 14.0, *)
struct ColorsEnvironmentKey: EnvironmentKey {
    static var defaultValue = Colors.testColors
}

@available(iOS 14.0, *)
extension EnvironmentValues {
    var colors: Colors {
        get { self[ColorsEnvironmentKey.self] }
        set { self[ColorsEnvironmentKey.self] = newValue }
    }
}
