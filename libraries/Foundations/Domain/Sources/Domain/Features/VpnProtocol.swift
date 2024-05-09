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

public enum OpenVpnTransport: String, Codable, CaseIterable, Sendable {
    case tcp = "tcp"
    case udp = "udp"

    public static let defaultValue: Self = .tcp
}

public enum WireGuardTransport: String, Codable, Equatable, CaseIterable, Sendable {
    case udp = "udp"
    case tcp = "tcp"
    case tls = "tls"

    public static let defaultValue: Self = .udp
}

public enum VpnProtocol: Equatable, Hashable, CaseIterable, Sendable, Codable {
    public static let allCases: [VpnProtocol] = [.ike]
        + OpenVpnTransport.allCases.map(Self.openVpn)
        + WireGuardTransport.allCases.map(Self.wireGuard)

    #if os(macOS)
    /// Set of protocols that are deprecated on macOS
    public static let deprecatedProtocols: [VpnProtocol] = OpenVpnTransport.allCases.map(Self.openVpn)
    #else
    /// Set of protocols that are deprecated on iOS and tvOS
    public static let deprecatedProtocols: [VpnProtocol] = [.ike] + OpenVpnTransport.allCases.map(Self.openVpn)
    #endif

    public var isDeprecated: Bool { Self.deprecatedProtocols.contains(self) }

    case ike
    case openVpn(OpenVpnTransport)
    case wireGuard(WireGuardTransport)

    enum Key: CodingKey {
        case rawValue
        case transportProtocol
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)

        switch rawValue {
        case 0:
            self = .ike
        case 1:
            let transportProtocol = try container.decode(OpenVpnTransport.self, forKey: .transportProtocol)
            self = .openVpn(transportProtocol)
        case 2:
            let transportProtocol = (try? container.decode(WireGuardTransport.self, forKey: .transportProtocol)) ?? .udp
            self = .wireGuard(transportProtocol)
        default:
            throw "CodingError.unknownValue"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)

        switch self {
        case .ike:
            try container.encode(0, forKey: .rawValue)
        case .openVpn(let transportProtocol):
            try container.encode(1, forKey: .rawValue)
            try container.encode(transportProtocol, forKey: .transportProtocol)
        case .wireGuard(let transportProtocol):
            try container.encode(2, forKey: .rawValue)
            try container.encode(transportProtocol, forKey: .transportProtocol)
        }
    }
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
