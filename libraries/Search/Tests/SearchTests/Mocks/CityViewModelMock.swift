//
//  Created on 16.03.2022.
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
import Search

final class CityViewModelMock: CityViewModel {
    var cityName: String

    var countryName: String

    var countryFlag: UIImage?

    let connectIcon: UIImage? = nil

    let textInPlaceOfConnectIcon: String? = nil

    let connectButtonColor: UIColor = .darkGray

    var connectionChanged: (() -> Void)?

    func updateTier() {

    }

    func connectAction() {

    }

    init(cityName: String, countryName: String = "") {
        self.cityName = cityName
        self.countryName = countryName
    }
}
