//
//  Created on 20/12/2022.
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

public struct TelemetryDimensions: Encodable {
    let outcome: Outcome
    let userTier: UserTier
    let vpnStatus: VPNStatus // This refers to whether a vpn connection is already ongoing when the connection action is triggered
    let vpnTrigger: VPNTrigger?
    let networkType: NetworkType
    let serverFeatures: ServerFeature // ordered comma-separated list
    let vpnCountry: String // ['CHE', 'FRA', 'NLD', ... ]
    let userCountry: String // ['CHE', 'FRA', 'NLD', ... ]
    let `protocol`: VpnProtocol
    let server: String // "#IT1"
    let port: String // 3360, max 25 char
    let isp: String // max 25 char

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(userTier, forKey: .userTier)
        try container.encode(vpnStatus, forKey: .vpnStatus)
        try container.encode(vpnTrigger, forKey: .vpnTrigger)
        try container.encode(networkType, forKey: .networkType)
        try container.encode(serverFeatures.commaSeparatedList, forKey: .serverFeatures)
        try container.encode(vpnCountry, forKey: .vpnCountry)
        try container.encode(userCountry, forKey: .userCountry)
        try container.encode(protocolString(`protocol`), forKey: .`protocol`)
        try container.encode(server, forKey: .server)
        try container.encode(port, forKey: .port)
        try container.encode(isp, forKey: .isp)
    }

    private func protocolString(_ protocol: VpnProtocol) -> String {
        switch `protocol` {
        case .ike:
            return "ikev2"
        case .openVpn(let openVpnTransport):
            switch openVpnTransport {
            case .tcp:
                return "openvpn_tcp"
            case .udp:
                return "openvpn_udp"
            }
        case .wireGuard(let wireGuardTransport):
            switch wireGuardTransport {
            case .tcp:
                return "wireguard_tcp"
            case .udp:
                return "wireguard_udp"
            case .tls:
                return "wireguard_tls"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case outcome = "outcome"
        case userTier = "user_tier"
        case vpnStatus = "vpn_status"
        case vpnTrigger = "vpn_trigger"
        case networkType = "network_type"
        case serverFeatures = "server_features"
        case vpnCountry = "vpn_country"
        case userCountry = "user_country"
        case `protocol` = "protocol"
        case server = "server"
        case port = "port"
        case isp = "isp"
    }

    enum Outcome: String, Encodable {
        case success
        case failure
    }

    enum UserTier: String, Encodable {
        case paid
        case free
        case `internal`
        case nonPaid = "non-paid"
    }

    enum VPNStatus: String, Encodable {
        case on
        case off
    }

    public enum VPNTrigger: String, Encodable {
        case quick
        case country
        case city
        case server
        case profile
        case map
        case tray
        case widget
        case auto
        case newConnection = "new_connection"
    }

    enum NetworkType: String, Encodable {
        case wifi
        case mobile
        case unavailable
    }
}
