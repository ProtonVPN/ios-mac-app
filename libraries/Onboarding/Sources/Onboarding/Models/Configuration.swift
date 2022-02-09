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
    public let background: UIColor
    public let text: UIColor
    public let brand: UIColor
    public let weakText: UIColor
    let activeBrandButton: UIColor
    let secondaryBackground: UIColor
    let textInverted: UIColor
    let notification: UIColor

    public init(background: UIColor, text: UIColor, brand: UIColor, weakText: UIColor, activeBrandButton: UIColor, secondaryBackground: UIColor, textInverted: UIColor, notification: UIColor) {
        self.background = background
        self.text = text
        self.brand = brand
        self.weakText = weakText
        self.activeBrandButton = activeBrandButton
        self.secondaryBackground = secondaryBackground
        self.textInverted = textInverted
        self.notification = notification
    }
}

public struct Constants {
    public let numberOfDevices: Int
    public let numberOfServers: Int
    let numberOfFreeServers: Int
    let numberOfFreeCountries: Int
    public let numberOfCountries: Int

    public init(numberOfDevices: Int, numberOfServers: Int, numberOfFreeServers: Int, numberOfFreeCountries: Int, numberOfCountries: Int) {
        self.numberOfDevices = numberOfDevices
        self.numberOfServers = numberOfServers
        self.numberOfFreeServers = numberOfFreeServers
        self.numberOfFreeCountries = numberOfFreeCountries
        self.numberOfCountries = numberOfCountries
    }
}

public struct Configuration {
    let variant: OnboardingVariant
    let colors: Colors
    let constants: Constants

    public init(variant: OnboardingVariant, colors: Colors, constants: Constants) {
        self.colors = colors
        self.variant = variant
        self.constants = constants
    }
}
