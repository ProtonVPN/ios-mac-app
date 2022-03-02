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

var colors: Colors!

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

let indicatorStyle: (UIActivityIndicatorView) -> Void = {
    $0.color = colors.weakText
}

let searchBarStyle: (UISearchBar) -> Void = {
    $0.backgroundImage = UIImage()
    if #available(iOS 13.0, *) {
        $0.searchTextField.textColor = colors.weakText
    } else {
        ($0.value(forKey: "searchField") as? UITextField)?.textColor = colors.weakText
    }
}
