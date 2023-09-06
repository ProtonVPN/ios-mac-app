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
import Theme

let baseButtonStyle: (UIButton) -> Void = {
    $0.layer.cornerRadius = 8
    $0.titleLabel?.font = .systemFont(ofSize: 17)
    $0.setTitleColor(.color(.text, .primary), for: .normal)
}

let brandStyle: (UIView) -> Void = {
    $0.backgroundColor = .color(.background, .interactive)
}

let brandStyleOnTint: (UISwitch) -> Void = {
    $0.onTintColor = .color(.background, .interactive)
}

let labelStyle: (UILabel) -> Void = {
    $0.font = .systemFont(ofSize: 15, weight: .regular)
    $0.textColor = .color(.text)
}

let smallLabelStyle: (UILabel) -> Void = {
    $0.font = .systemFont(ofSize: 11, weight: .regular)
    $0.textColor = .color(.text)
}

let baseViewStyle: (UIView) -> Void = {
    $0.backgroundColor = .color(.background)
}

let actionButtonStyle = concat(baseButtonStyle, brandStyle, and: {
    $0.heightAnchor.constraint(equalToConstant: 48).isActive = true
})

let textButtonStyle: (UIButton) -> Void = {
    $0.titleLabel?.font = .systemFont(ofSize: 17)
    $0.setTitleColor(.color(.text, .interactive), for: .normal)
}

let actionTextButtonStyle = concat(textButtonStyle, and: {
    $0.heightAnchor.constraint(equalToConstant: 48).isActive = true
    $0.titleLabel?.font = .systemFont(ofSize: 15)
})

let baseTextStyle: (UILabel) -> Void = {
    $0.font = .systemFont(ofSize: 17)
    $0.textColor = .color(.text)
    $0.numberOfLines = 0
}

let centeredTextStyle = concat(baseTextStyle, and: {
    $0.textAlignment = .center
})

let titleStyle = concat(centeredTextStyle, and: {
    $0.font = .systemFont(ofSize: 22, weight: .bold)
})

let subtitleStyle = concat(centeredTextStyle, and: {
    $0.font = .systemFont(ofSize: 17, weight: .regular)
    $0.textColor = colors.weakText
})

let footerStyle = concat(baseTextStyle, and: {
    $0.textColor = .color(.text, .weak)
    $0.font = .systemFont(ofSize: 13)
})

let featureTextStyle = concat(baseTextStyle, and: {
    $0.font = .systemFont(ofSize: 15, weight: .regular)
})

let closeButtonStyle: (UIButton) -> Void = {
    $0.titleLabel?.text = ""
    $0.setTitleColor(colors.textAccent, for: .normal)
    $0.tintColor = colors.text
}

let shevronStyle: (UIImageView) -> Void = {
    $0.image = UIImage(systemName: "chevron.right")
    $0.tintColor = colors.weakText
}

let smallFlagStyle: (UIImageView) -> Void = {
    $0.layer.cornerRadius = 4
    $0.layer.masksToBounds = true
}
