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
    case multipleDevices
    case netshield
    case highSpeed
}

extension Feature: CaseIterable {
    func title(constants: UpsellConstantsProtocol) -> String {
        switch self {
        case .streaming:
            return LocalizedString.onboardingUpsellFeatureStreaming
        case .multipleDevices:
            return LocalizedString.onboardingUpsellFeatureMultipleDevices(constants.numberOfDevices)
        case .netshield:
            return LocalizedString.onboardingUpsellFeatureNetshield
        case .highSpeed:
            return LocalizedString.onboardingUpsellFeatureHighSpeed
        }
    }

    var image: UIImage {
        switch self {
        case .streaming:
            return UIImage(named: "StreamingIcon", in: Bundle.module, compatibleWith: nil)!
        case .multipleDevices:
            return UIImage(named: "MultipleDevicesIcon", in: Bundle.module, compatibleWith: nil)!
        case .netshield:
            return UIImage(named: "NetshieldIcon", in: Bundle.module, compatibleWith: nil)!
        case .highSpeed:
            return UIImage(named: "HighSpeedIcon", in: Bundle.module, compatibleWith: nil)!
        }
    }
}
