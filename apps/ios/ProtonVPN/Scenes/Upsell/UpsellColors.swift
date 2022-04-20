//
//  Created on 14/02/2022.
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

import UIKit
import Modals
import Modals_iOS
import ProtonCore_UIFoundations

struct UpsellColors: ModalsColors {
    var background: UIColor
    var secondaryBackground: UIColor
    var text: UIColor
    var textAccent: UIColor
    var brand: UIColor
    var weakText: UIColor

    init() {
        background = UIColor.backgroundColor()
        secondaryBackground = UIColor.secondaryBackgroundColor()
        text = UIColor.normalTextColor()
        textAccent = UIColor.textAccent()
        brand = UIColor.brandColor()
        weakText = UIColor.weakTextColor()
    }
}
