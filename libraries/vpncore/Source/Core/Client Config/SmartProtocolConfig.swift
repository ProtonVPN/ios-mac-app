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
import Logging

public struct SmartProtocolConfig: Codable, Equatable, DefaultableProperty {
    public let openVPN: Bool
    public let iKEv2: Bool
    public let wireGuard: Bool
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

        if wireGuard {
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
        case wireGuard
        case wireGuardTcp = "WireGuardTCP"
        case wireGuardTls = "WireGuardTLS"
    }

    public init(openVPN: Bool, iKEv2: Bool, wireGuard: Bool, wireGuardTcp: Bool, wireGuardTls: Bool) {
        self.openVPN = openVPN
        self.iKEv2 = iKEv2
        self.wireGuard = wireGuard
        self.wireGuardTcp = wireGuardTcp
        self.wireGuardTls = wireGuardTls
    }

    public init() {
        self.init(openVPN: true,
                  iKEv2: true,
                  wireGuard: true,
                  wireGuardTcp: true,
                  wireGuardTls: true)
    }
    
    public func configWithWireGuard(enabled: Bool? = nil, tlsEnabled: Bool? = nil) -> SmartProtocolConfig {
        // If enabled is specified, use that value. Otherwise, use the existing config value in
        // this object.
        let wireGuardEnabled = enabled ?? wireGuard
        var wireGuardTlsEnabled = false
        // If wireGuard has been enabled via the above, set WGTLS' enablement according to
        // the passed value, or, if none was provided, the existing config value in this object.
        // Set WGTCP's enablement to the same, since they're part of the same feature.
        if wireGuardEnabled {
            wireGuardTlsEnabled = tlsEnabled ?? wireGuardTls
        }

        return SmartProtocolConfig(openVPN: openVPN,
                                   iKEv2: iKEv2,
                                   wireGuard: wireGuardEnabled,
                                   wireGuardTcp: wireGuardTlsEnabled,
                                   wireGuardTls: wireGuardTlsEnabled)
    }

    public static func == (lhs: SmartProtocolConfig, rhs: SmartProtocolConfig) -> Bool {
        lhs.openVPN == rhs.openVPN &&
        lhs.iKEv2 == rhs.iKEv2 &&
        lhs.wireGuard == rhs.wireGuard &&
        lhs.wireGuardTls == rhs.wireGuardTls
    }
}
