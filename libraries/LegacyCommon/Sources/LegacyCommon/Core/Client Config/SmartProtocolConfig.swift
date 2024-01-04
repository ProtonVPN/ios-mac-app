//
//  SmartProtocolConfig.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

import Domain
import VPNShared

public struct SmartProtocolConfig: Codable, Equatable, DefaultableProperty {
    public let openVPN: Bool
    public let iKEv2: Bool
    public let wireGuardUdp: Bool
    @Default<BoolDefaultTrue> public var wireGuardTcp: Bool
    @Default<BoolDefaultTrue> public var wireGuardTls: Bool

    public var supportedProtocols: [VpnProtocol] {
        var result: [VpnProtocol] = []

        if openVPN {
            result.append(contentsOf: [.openVpn(.tcp), .openVpn(.udp)])
        }

        if iKEv2 {
            result.append(.ike)
        }

        if wireGuardUdp {
            result.append(.wireGuard(.udp))
        }

        if wireGuardTcp {
            result.append(.wireGuard(.tcp))
        }

        if wireGuardTls {
            result.append(.wireGuard(.tls))
        }

        return result
    }

    enum CodingKeys: String, CodingKey {
        case openVPN
        case iKEv2 = "IKEv2"
        case wireGuardUdp = "wireGuard"
        case wireGuardTcp = "wireGuardTCP"
        case wireGuardTls = "wireGuardTLS"
    }

    public init(openVPN: Bool, iKEv2: Bool, wireGuardUdp: Bool, wireGuardTcp: Bool, wireGuardTls: Bool) {
        self.openVPN = openVPN
        self.iKEv2 = iKEv2
        self.wireGuardUdp = wireGuardUdp
        self.wireGuardTcp = wireGuardTcp
        self.wireGuardTls = wireGuardTls
    }

    public init() {
        self.init(openVPN: true,
                  iKEv2: true,
                  wireGuardUdp: true,
                  wireGuardTcp: true,
                  wireGuardTls: true)
    }

    public func configWithWireGuard(udpEnabled: Bool? = nil, tcpEnabled: Bool? = nil, tlsEnabled: Bool? = nil) -> SmartProtocolConfig {
        return SmartProtocolConfig(openVPN: openVPN,
                                   iKEv2: iKEv2,
                                   wireGuardUdp: udpEnabled ?? wireGuardUdp,
                                   wireGuardTcp: tcpEnabled ?? wireGuardTcp,
                                   wireGuardTls: tlsEnabled ?? wireGuardTls)
    }

    public static func == (lhs: SmartProtocolConfig, rhs: SmartProtocolConfig) -> Bool {
        lhs.openVPN == rhs.openVPN &&
        lhs.iKEv2 == rhs.iKEv2 &&
        lhs.wireGuardUdp == rhs.wireGuardUdp &&
        lhs.wireGuardTls == rhs.wireGuardTls
    }
}
