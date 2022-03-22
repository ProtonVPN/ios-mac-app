//
//  Created on 14.03.2022.
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
@testable import Search

final class ServerViewModelMock: ServerViewModel {
    let description: String

    let isSmartAvailable: Bool = false

    let torAvailable: Bool = false

    let p2pAvailable: Bool = false

    let streamingAvailable: Bool = false

    let connectIcon: UIImage? = nil

    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? "UPGRADE" : nil
    }

    var connectionChanged: (() -> Void)?

    let alphaOfMainElements: CGFloat = 1

    let isUsersTierTooLow: Bool

    let underMaintenance: Bool = false

    let connectButtonColor: UIColor = .darkGray

    let loadValue: String = "56%"

    let loadColor: UIColor = .green

    let city: String

    let entryCountryName: String?

    let entryCountryFlag: UIImage? = nil

    let countryFlag: UIImage? = nil

    let countryName: String

    let translatedCity: String?

    func updateTier() {

    }

    func connectAction() {

    }

    init(server: String, city: String, countryName: String, isUsersTierTooLow: Bool = false, entryCountryName: String? = nil, translatedCity: String? = nil) {
        description = server
        self.city = city
        self.countryName = countryName
        self.isUsersTierTooLow = isUsersTierTooLow
        self.entryCountryName = entryCountryName
        self.translatedCity = translatedCity
    }
}
