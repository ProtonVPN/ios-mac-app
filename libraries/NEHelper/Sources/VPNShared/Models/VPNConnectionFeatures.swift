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

public struct VPNConnectionFeatures: Equatable {
    public let netshield: NetShieldType
    public let vpnAccelerator: Bool
    public let bouncing: String?
    public let natType: NATType
    public let safeMode: Bool?

    public init(netshield: NetShieldType, vpnAccelerator: Bool, bouncing: String?, natType: NATType, safeMode: Bool?) {
        self.netshield = netshield
        self.vpnAccelerator = vpnAccelerator
        self.bouncing = bouncing
        self.natType = natType
        self.safeMode = safeMode
    }

    /// Used for testing purposes.
    public var asDict: [String: Any] {
        var result = [String: Any]()
        result[CodingKeys.netshield.rawValue] = netshield.rawValue
        result[CodingKeys.vpnAccelerator.rawValue] = vpnAccelerator
        if let bouncing = bouncing {
            result[CodingKeys.bouncing.rawValue] = bouncing
        }
        result[CodingKeys.natType.rawValue] = natType.flag
        if let safeMode = safeMode {
            result[CodingKeys.safeMode.rawValue] = safeMode
        }
        return result
    }

    public func copyWithChanged(bouncing: String?) -> Self {
        return Self(netshield: netshield,
                    vpnAccelerator: vpnAccelerator,
                    bouncing: bouncing,
                    natType: natType,
                    safeMode: safeMode)
    }
}

extension VPNConnectionFeatures: Codable {
    enum CodingKeys: String, CodingKey {
        case netshield = "NetShieldLevel"
        case vpnAccelerator = "SplitTCP"
        case bouncing = "Bouncing"
        case natType = "RandomNAT"
        case safeMode = "SafeMode"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        netshield = try values.decode(NetShieldType.self, forKey: .netshield)
        vpnAccelerator = try values.decode(Bool.self, forKey: .vpnAccelerator)
        bouncing = try values.decodeIfPresent(String.self, forKey: .bouncing)
        if let natTypeValue = try values.decodeIfPresent(NATType.self, forKey: .natType) {
            natType = natTypeValue
        } else {
            natType = .default
        }
        safeMode = try values.decodeIfPresent(Bool.self, forKey: .safeMode)
    }
}

extension VPNConnectionFeatures {
    public func equals(other: VPNConnectionFeatures?, safeModeFeatureEnabled: Bool) -> Bool {
        let equalsWithoutSafeMode = self.netshield == other?.netshield && self.vpnAccelerator == other?.vpnAccelerator && self.bouncing == other?.bouncing && self.natType == other?.natType

        // if Safe Mode is disabled by feature flag ignore it when doing the comparison
        // this is needed for the situation when Safe Mode is set to nil because of the feature flag but the Local Agent sends back false (the default value),
        // without this check it would cause the certificate to be regenerated for no good reason
        guard safeModeFeatureEnabled else {
            return equalsWithoutSafeMode
        }

        return equalsWithoutSafeMode && self.safeMode == other?.safeMode
    }
}
