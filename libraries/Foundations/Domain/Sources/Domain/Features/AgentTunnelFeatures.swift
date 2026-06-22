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

public struct AgentTunnelFeatures: Equatable, Sendable {
    public private(set) var netshield: NetShieldType
    public private(set) var vpnAccelerator: Bool
    public private(set) var natType: NATType
    public private(set) var portForwarding: Bool?

    public init(netshield: NetShieldType, vpnAccelerator: Bool, natType: NATType, portForwarding: Bool?) {
        self.netshield = netshield
        self.vpnAccelerator = vpnAccelerator
        self.natType = natType
        self.portForwarding = portForwarding
    }

    /// Used for testing purposes.
    public var asDict: [String: Any] {
        var result = [String: Any]()
        result[CodingKeys.netshield.rawValue] = netshield.rawValue
        result[CodingKeys.vpnAccelerator.rawValue] = vpnAccelerator
        result[CodingKeys.natType.rawValue] = natType.flag
        if let portForwarding {
            result[CodingKeys.portForwarding.rawValue] = portForwarding
        }
        return result
    }

    public func copy<V>(with changes: (field: WritableKeyPath<AgentTunnelFeatures, V>, newValue: V)...) -> Self {
        var copy = self
        changes.forEach { copy[keyPath: $0.field] = $0.newValue }
        return copy
    }
}

extension AgentTunnelFeatures: Codable {
    enum CodingKeys: String, CodingKey {
        case netshield = "NetShieldLevel"
        case vpnAccelerator = "SplitTCP"
        case natType = "RandomNAT"
        case portForwarding = "PortForwarding"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.netshield = try values.decode(NetShieldType.self, forKey: .netshield)
        self.vpnAccelerator = try values.decode(Bool.self, forKey: .vpnAccelerator)
        if let natTypeValue = try values.decodeIfPresent(NATType.self, forKey: .natType) {
            self.natType = natTypeValue
        } else {
            self.natType = .default
        }
        self.portForwarding = try values.decodeIfPresent(Bool.self, forKey: .portForwarding)
    }
}

public extension AgentTunnelFeatures {
    func equals(other: AgentTunnelFeatures?) -> Bool {
        netshield == other?.netshield && vpnAccelerator == other?.vpnAccelerator && natType == other?.natType && portForwarding == other?.portForwarding
    }
}
