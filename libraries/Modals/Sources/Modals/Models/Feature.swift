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
import UIKit

enum Feature {
    case streaming
    case multipleDevices(Int)
    case netshield
    case highSpeed
    case blockAds
    case protectFromMalware
    case highSpeedNetshield
    case routeSecureServers
    case addLayer
    case protectFromAttacks
}

extension Feature {
    func title() -> String {
        switch self {
        case .streaming:
            return LocalizedString.modalsUpsellAllCountriesFeatureStreaming
        case .multipleDevices(let numberOfDevices):
            return LocalizedString.modalsUpsellAllCountriesFeatureMultipleDevices(numberOfDevices)
        case .netshield:
            return LocalizedString.modalsUpsellAllCountriesFeatureNetshield
        case .highSpeed:
            return LocalizedString.modalsUpsellAllCountriesFeatureHighSpeed
        case .blockAds:
            return LocalizedString.modalsUpsellNetShieldAds
        case .protectFromMalware:
            return LocalizedString.modalsUpsellNetShieldMalware
        case .highSpeedNetshield:
            return LocalizedString.modalsUpsellNetShieldHighSpeed
        case .routeSecureServers:
            return LocalizedString.modalsUpsellSecureCoreRoute
        case .addLayer:
            return LocalizedString.modalsUpsellSecureCoreLayer
        case .protectFromAttacks:
            return LocalizedString.modalsUpsellSecureCoreAttacks
        }
    }

    var image: UIImage {
        let imageName: String
        switch self {
        case .streaming:
            imageName = "StreamingIcon"
        case .multipleDevices:
            imageName = "MultipleDevicesIcon"
        case .netshield:
            imageName = "NetshieldIcon"
        case .highSpeed:
            imageName = "HighSpeedIcon"
        case .blockAds:
            imageName = "BlockAds"
        case .protectFromMalware:
            imageName = "NetshieldIcon"
        case .highSpeedNetshield:
            imageName = "HighSpeedIcon"
        case .routeSecureServers:
            imageName = "RouteSecureServers"
        case .addLayer:
            imageName = "AddLayer"
        case .protectFromAttacks:
            imageName = "ProtectFromAttacks"
        }
        return UIImage(named: imageName, in: Bundle.module, compatibleWith: nil)!
    }
}
