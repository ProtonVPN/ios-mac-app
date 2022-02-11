//
//  Created on 11/02/2022.
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

public enum UpsellType {
    case netShield
    case secureCore
    case allCountries(UpsellConstantsProtocol)

    func upsellFeature() -> UpsellFeature {
        switch self {
        case .netShield:
            let title = LocalizedString.modalsUpsellNetShieldTitle
            let features: [Feature] = [.blockAds, .protectFromMalware, .highSpeedNetshield]
            let artImage = UIImage(named: "NetShield", in: Bundle.module, compatibleWith: nil)!
            return UpsellFeature(title: title, features: features, artImage: artImage, footer: nil)
        case .secureCore:
            let title = LocalizedString.modalsUpsellSecureCoreTitle
            let features: [Feature] = [.routeSecureServers, .addLayer, .protectFromAttacks]
            let artImage = UIImage(named: "SecureCore", in: Bundle.module, compatibleWith: nil)!
            return UpsellFeature(title: title, features: features, artImage: artImage, footer: nil)
        case .allCountries(let constants):
            let title = LocalizedString.modalsUpsellAllCountriesTitle(constants.numberOfServers, constants.numberOfCountries)
            let features: [Feature] = [.streaming, .multipleDevices(constants.numberOfDevices), .netshield, .highSpeed]
            let artImage = UIImage(named: "PlusCountries", in: Bundle.module, compatibleWith: nil)!
            let footer = LocalizedString.modalsUpsellFeaturesFooter
            return UpsellFeature(title: title, features: features, artImage: artImage, footer: footer)
        }
    }
}
