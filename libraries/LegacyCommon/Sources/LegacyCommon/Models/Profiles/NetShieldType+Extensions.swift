//
//  Created on 2021-12-07.
//
//  Copyright (c) 2021 Proton AG
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

import ProtonCoreUIFoundations

import Domain
import Strings
import VPNShared

public extension NetShieldType {
    var name: String {
        switch self {
        case .off:
            Localizable.netshieldOff
        case .level1:
            Localizable.netshieldLevel1
        case .level2:
            Localizable.netshieldLevel2
        }
    }

    var icon: Image {
        switch self {
        case .off: IconProvider.shield
        case .level1: IconProvider.shieldHalfFilled
        case .level2: IconProvider.shieldFilled
        }
    }

    var lowestTier: Int {
        switch self {
        case .off:
            .freeTier
        default:
            .paidTier
        }
    }

    func isUserTierTooLow(_ userTier: Int) -> Bool {
        userTier < lowestTier
    }

    var vpnManagerClientConfigurationFlags: [VpnManagerClientConfiguration] {
        switch self {
        case .off:
            []
        case .level1:
            [.netShieldLevel1]
        case .level2:
            [.netShieldLevel2]
        }
    }
}
