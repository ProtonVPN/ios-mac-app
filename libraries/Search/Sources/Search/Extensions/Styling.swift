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
import Overture

var colors = Colors()

let baseTextStyle: (UILabel) -> Void = {
    $0.font = .systemFont(ofSize: 17)
    $0.textColor = colors.text
    $0.numberOfLines = 0
}

let baseViewStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.background
}

let centeredTextStyle = concat(baseTextStyle, and: {
    $0.textAlignment = .center
})

let titleStyle = concat(centeredTextStyle, and: {
    $0.font = .systemFont(ofSize: 22, weight: .bold)
})

let subtitleStyle = concat(centeredTextStyle, and: {
    $0.font = .systemFont(ofSize: 15)
    $0.textColor = colors.weakText
})

let searchBarStyle: (UISearchBar) -> Void = {
    $0.backgroundImage = UIImage()
    $0.tintColor = colors.weakText
    let searchField = $0.searchTextField
    searchField.textColor = colors.weakText
    searchField.backgroundColor = colors.secondaryBackground
}

let textButtonStyle: (UIButton) -> Void = {
    $0.titleLabel?.font = .systemFont(ofSize: 15)
    $0.setTitleColor(colors.brand, for: .normal)
}

let cellHeaderStyle = concat(subtitleStyle, and: {
    $0.textAlignment = .left
    $0.textColor = colors.weakText
})

let upsellViewStyle: (UIView) -> Void = {
    $0.backgroundColor = colors.secondaryBackground
    $0.layer.cornerRadius = 12
}

let iconWeakStyle: (UIView) -> Void = {
    $0.tintColor = UIColor(red: 167 / 255, green: 164 / 255, blue: 181 / 255, alpha: 1) // colors.iconWeak
}

let iconHintStyle: (UIView) -> Void = {
    $0.tintColor = UIColor(red: 109 / 255, green: 105 / 255, blue: 125 / 255, alpha: 1) // colors.iconHint
}

let upsellSubtitleStyle = concat(baseTextStyle, and: {
    $0.textColor = colors.weakText
    $0.font = UIFont.systemFont(ofSize: 13)
})

let upsellTitleStyle = concat(baseTextStyle, and: {
    $0.font = UIFont.systemFont(ofSize: 15)
})

let lineSeparatorStyle: (UIView, NSLayoutConstraint) -> Void = {
    $0.backgroundColor = colors.separator
    $1.constant = 1 / UIScreen.main.scale // UIScreen.main.scale is either 1, 2 or 3 for screens 1x, 2x and 3x. This way we're always getting a 1 pixel value.
}

let highlightMatches = { (label: UILabel, string: String?, searchText: String?) in
    guard let searchText = searchText, !searchText.isEmpty, let string = string, !string.isEmpty else {
        label.text = string
        return
    }

    let text = NSMutableAttributedString(string: string, attributes: [
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17),
        NSAttributedString.Key.foregroundColor: colors.weakText
    ])

    string.findStartingRanges(of: searchText).forEach {
        text.addAttributes([NSAttributedString.Key.foregroundColor: colors.text], range: $0)
    }

    label.attributedText = text
}
