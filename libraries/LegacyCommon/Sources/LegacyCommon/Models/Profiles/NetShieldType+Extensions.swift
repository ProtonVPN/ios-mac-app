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

extension NetShieldType {
    
    public var name: String {
        switch self {
        case .off:
            return Localizable.netshieldOff
        case .level1:
            return Localizable.netshieldLevel1
        case .level2:
            return Localizable.netshieldLevel2
        }
    }

    public var icon: Image {
        switch self {
        case .off: return IconProvider.shield
        case .level1: return IconProvider.shieldHalfFilled
        case .level2: return IconProvider.shieldFilled
        }
    }
    
    public var lowestTier: Int {
        switch self {
        case .off:
            return .freeTier
        default:
            return .paidTier
        }
    }
    
    public func isUserTierTooLow(_ userTier: Int) -> Bool {
        return userTier < self.lowestTier
    }
    
    public var vpnManagerClientConfigurationFlags: [VpnManagerClientConfiguration] {
        switch self {
        case .off:
            return []
        case .level1:
            return [.netShieldLevel1]
        case .level2:
            return [.netShieldLevel2]
        }
    }
}
