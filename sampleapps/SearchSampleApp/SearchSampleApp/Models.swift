//
//  Created on 03.03.2022.
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
import Search
import UIKit

struct CountryModel: Country {
    let name: String
}

struct ServerModel: Server {
    let name: String
}

final class CountryItemViewModel: CountryCellViewModel {
    let description: String

    let isSmartAvailable: Bool = false

    let torAvailable: Bool = false

    let p2pAvailable: Bool = false

    let connectIcon: UIImage? = UIImage(named: "con-available")

    let textInPlaceOfConnectIcon: String? = nil

    var connectionChanged: (() -> Void)?

    let alphaOfMainElements: CGFloat = 1

    let flag: UIImage? = UIImage(named: "ch-plain")

    let connectButtonColor: UIColor = .darkGray

    let textColor: UIColor = .white

    func updateTier() {

    }

    func connectAction() {

    }

    init(country: Country) {
        description = country.name
    }
}
