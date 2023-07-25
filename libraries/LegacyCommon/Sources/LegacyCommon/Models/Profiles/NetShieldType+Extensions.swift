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
import VPNShared
import ProtonCoreUIFoundations

extension NetShieldType {
    
    public var name: String {
        switch self {
        case .off:
            return LocalizedString.netshieldOff
        case .level1:
            return LocalizedString.netshieldLevel1
        case .level2:
            return LocalizedString.netshieldLevel2
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
            return CoreAppConstants.VpnTiers.free
        case .level1:
            return CoreAppConstants.VpnTiers.basic
        case .level2:
            return CoreAppConstants.VpnTiers.basic
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
    
    // MARK: - NSCoding
    
    private enum CoderKey: String, CodingKey {
        case netShieldType = "NetShieldType"
    }
        
    public func encode(with aCoder: NSCoder) {
        var data = Data(count: 1)
        data[0] = UInt8(self.rawValue)
        aCoder.encode(data, forKey: CoderKey.netShieldType.rawValue)
    }
    
    public static func decodeIfPresent(coder aDecoder: NSCoder) -> NetShieldType? {
        guard let data = aDecoder.decodeObject(forKey: CoderKey.netShieldType.rawValue) as? Data else {
            return nil
        }
        return NetShieldType.init(rawValue: Int(data[0]))
    }
    
}
