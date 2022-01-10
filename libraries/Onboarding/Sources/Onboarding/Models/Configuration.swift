//
//  Created on 04.01.2022.
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

public struct Colors {
    let background: UIColor
    let text: UIColor
    let brand: UIColor
    let weakText: UIColor
    let activeBrandButton: UIColor
    let secondaryBackground: UIColor

    public init(background: UIColor, text: UIColor, brand: UIColor, weakText: UIColor, activeBrandButton: UIColor, secondaryBackground: UIColor) {
        self.background = background
        self.text = text
        self.brand = brand
        self.weakText = weakText
        self.activeBrandButton = activeBrandButton
        self.secondaryBackground = secondaryBackground
    }
}

public struct Configuration {
    let variant: OnboardingVariant
    let colors: Colors

    public init(variant: OnboardingVariant, colors: Colors) {
        self.colors = colors
        self.variant = variant
    }
}
