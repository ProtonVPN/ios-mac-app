//
//  Created on 2/8/22.
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
import Overture
import UIKit

var colors: Colors = Colors(background: .black,
                            text: .white,
                            brand: UIColor(red: 77/255, green: 163/255, blue: 88/255, alpha: 1),
                            weakText: UIColor(red: 156/255, green: 160/255, blue: 170/255, alpha: 1),
                            activeBrandButton: UIColor(red: 133/255, green: 181/255, blue: 121/255, alpha: 1),
                            secondaryBackground: UIColor(red: 37/255, green: 39/255, blue: 44/255, alpha: 1),
                            textInverted: .black,
                            notification: .white)

var constants: Constants = Constants(numberOfDevices: 10,
                                     numberOfServers: 1300,
                                     numberOfFreeServers: 23,
                                     numberOfFreeCountries: 3,
                                     numberOfCountries: 61)

let baseButtonStyle: (UIButton) -> Void = {
    $0.layer.cornerRadius = 8
    $0.titleLabel?.font = .systemFont(ofSize: 17)
    $0.setTitleColor(colors.text, for: .normal)
}

let brandStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.brand
}

let baseViewStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.background
}

let actionButtonStyle = concat(baseButtonStyle, brandStyle, and: {
    $0.heightAnchor.constraint(equalToConstant: 48).isActive = true
})

let textButtonStyle: (UIButton) -> Void = {
    $0.titleLabel?.font = .systemFont(ofSize: 17)
    $0.setTitleColor(colors.brand, for: .normal)
}

let actionTextButtonStyle = concat(textButtonStyle, and: {
    $0.titleLabel?.font = .systemFont(ofSize: 15)
})

let baseTextStyle: (UILabel) -> Void = {
    $0.font = .systemFont(ofSize: 17)
    $0.textColor = colors.text
    $0.numberOfLines = 0
}

let centeredTextStyle = concat(baseTextStyle, and: {
    $0.textAlignment = .center
})

let titleStyle = concat(centeredTextStyle, and: {
    $0.font = .systemFont(ofSize: 22, weight: .bold)
})

let footerStyle = concat(baseTextStyle, and: {
    $0.textColor = colors.weakText
    $0.font = .systemFont(ofSize: 13)
})

let featureTextStyle = concat(baseTextStyle, and: {
    $0.font = .systemFont(ofSize: 14, weight: .semibold)
})
