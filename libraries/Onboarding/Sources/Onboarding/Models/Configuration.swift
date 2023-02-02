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
import SwiftUI

public struct Colors {
    public let background: UIColor
    public let text: UIColor
    public let brand: UIColor
    public let weakText: UIColor
    public var textAccent: UIColor
    public let weakInteraction: UIColor
    let activeBrandButton: UIColor
    public let secondaryBackground: UIColor
    let textInverted: UIColor
    let notification: UIColor

    public init(background: UIColor, text: UIColor, textAccent: UIColor, brand: UIColor, weakText: UIColor, activeBrandButton: UIColor, secondaryBackground: UIColor, textInverted: UIColor, notification: UIColor, weakInteraction: UIColor) {
        self.background = background
        self.text = text
        self.textAccent = textAccent
        self.brand = brand
        self.weakText = weakText
        self.activeBrandButton = activeBrandButton
        self.secondaryBackground = secondaryBackground
        self.textInverted = textInverted
        self.notification = notification
        self.weakInteraction = weakInteraction
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
    let colors: Colors
    let constants: Constants
    let telemetryEnabled: Bool

    public init(colors: Colors,
                constants: Constants,
                telemetryEnabled: Bool) {
        self.colors = colors
        self.constants = constants
        self.telemetryEnabled = telemetryEnabled
    }
}

extension UIColor {
    var suColor: Color { Color(self) }
}

let previewColors = Colors(background: UIColor(red: 28/255, green: 27/255, blue: 35/255, alpha: 1),
                           text: .white,
                           textAccent: UIColor(red: 138 / 255, green: 110 / 255, blue: 255 / 255, alpha: 1),
                           brand: UIColor(red: 0.427451, green: 0.290196, blue: 1, alpha: 1),
                           weakText: UIColor(red: 0.654902, green: 0.643137, blue: 0.709804, alpha: 1),
                           activeBrandButton: UIColor(red: 133/255, green: 181/255, blue: 121/255, alpha: 1),
                           secondaryBackground: UIColor(red: 41/255, green: 39/255, blue: 50/255, alpha: 1),
                           textInverted: .black,
                           notification: .white,
                           weakInteraction: UIColor(red: 59 / 255, green: 55 / 255, blue: 71 / 255, alpha: 1))
