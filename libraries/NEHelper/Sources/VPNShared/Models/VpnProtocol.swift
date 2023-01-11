//
//  Created on 11.01.23.
//
//  Copyright (c) 2023 Proton AG
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

public enum OpenVpnTransport: String, Codable, CaseIterable {
    case tcp = "tcp"
    case udp = "udp"

    public static let defaultValue: Self = .tcp
}

public enum WireGuardTransport: String, Codable, Equatable, CaseIterable {
    case udp = "udp"
    case tcp = "tcp"
    case tls = "tls"

    public static let defaultValue: Self = .udp
}

public enum VpnProtocol: Equatable, Hashable, CaseIterable {
    public static let allCases: [VpnProtocol] = [.ike]
        + OpenVpnTransport.allCases.map(Self.openVpn)
        + WireGuardTransport.allCases.map(Self.wireGuard)

    case ike
    case openVpn(OpenVpnTransport)
    case wireGuard(WireGuardTransport)
}

// MARK: - Default values

extension VpnProtocol {
#if os(iOS)
    public static let defaultValue: Self = .openVpn(.udp)
#else
    public static let defaultValue: Self = .ike
#endif
}

// MARK: - API description
extension VpnProtocol {
    public var apiDescription: String {
        switch self {
        case .ike:
            return "IKEv2"
        case .openVpn(let transport):
            return "OpenVPN" + transport.rawValue.uppercased()
        case .wireGuard(let transport):
            return "WireGuard" + transport.rawValue.uppercased()
        }
    }

    public init?(apiDescription: String) {
        switch apiDescription {
        case "IKEv2":
            self = .ike
        case "OpenVPNUDP":
            self = .openVpn(.udp)
        case "OpenVPNTCP":
            self = .openVpn(.tcp)
        case "WireGuardUDP":
            self = .wireGuard(.udp)
        case "WireGuardTCP":
            self = .wireGuard(.tcp)
        case "WireGuardTLS":
            self = .wireGuard(.tls)
        default:
            return nil
        }
    }
}
