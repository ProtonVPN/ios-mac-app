//
//  Created on 2023-09-06.
//
//  Copyright (c) 2023 Proton AG
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
import Modals

class CountryCellView: UICollectionViewCell {

    static var identifier: String { return String(describing: self) }

    @IBOutlet private weak var flagImageView: UIImageView!
    @IBOutlet private weak var countryNameField: UILabel!

    public func setCountry(_ country: String, image: Image?) {
        countryNameField.text = country
        flagImageView.image = image
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        labelStyle(countryNameField)
        smallFlagStyle(flagImageView)
    }

}
