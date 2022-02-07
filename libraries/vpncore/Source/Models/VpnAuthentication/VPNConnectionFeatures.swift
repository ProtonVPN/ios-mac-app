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
    let netshield: NetShieldType
    let vpnAccelerator: Bool
    let bouncing: String?
    let natType: NATType

    init(netshield: NetShieldType, vpnAccelerator: Bool, bouncing: String?, natType: NATType) {
        self.netshield = netshield
        self.vpnAccelerator = vpnAccelerator
        self.bouncing = bouncing
        self.natType = natType
    }
    
    /// Default features
    init() {
        self.netshield = .level1
        self.vpnAccelerator = true
        self.bouncing = nil
        self.natType = .default
    }
    
    var asDict: [String: Any] {
        var result = [String: Any]()
        result[CodingKeys.netshield.rawValue] = netshield.rawValue
        result[CodingKeys.vpnAccelerator.rawValue] = vpnAccelerator
        if let bouncing = bouncing {
            result[CodingKeys.bouncing.rawValue] = bouncing
        }
        result[CodingKeys.natType.rawValue] = natType.flag
        return result
    }
}

extension VPNConnectionFeatures: Codable {
    enum CodingKeys: String, CodingKey {
        case netshield = "NetShieldLevel"
        case vpnAccelerator = "SplitTCP"
        case bouncing = "Bouncing"
        case natType = "RandomNAT"
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
    }
}
