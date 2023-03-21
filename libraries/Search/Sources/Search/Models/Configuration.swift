//
//  Created on 02.03.2022.
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
import UIKit
import Theme

public struct Constants {
    let numberOfCountries: Int

    public init(numberOfCountries: Int) {
        self.numberOfCountries = numberOfCountries
    }
}

public struct Colors {
    let background: UIColor
    let text: UIColor
    let brand: UIColor
    let weakText: UIColor
    let separator: UIColor
    let secondaryBackground: UIColor
    let iconWeak: UIColor

    public init() {
        self.background = ColorPaletteiOS.instance.BackgroundNorm
        self.text = ColorPaletteiOS.instance.TextNorm
        self.brand = ColorPaletteiOS.instance.BrandNorm
        self.weakText = ColorPaletteiOS.instance.TextWeak
        self.separator = ColorPaletteiOS.instance.SeparatorNorm
        self.secondaryBackground = ColorPaletteiOS.instance.BackgroundSecondary
        self.iconWeak = ColorPaletteiOS.instance.IconWeak
    }
}

public struct Configuration {
    let constants: Constants

    public init(constants: Constants) {
        self.constants = constants
    }
}
