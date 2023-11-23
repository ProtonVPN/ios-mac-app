//
//  Created on 05/07/2023.
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

import Strings
import VPNShared

public enum ConnectionProtocol: Equatable, Hashable, CaseIterable, Sendable, Codable {
    case vpnProtocol(VpnProtocol)
    case smartProtocol

    private enum Keys: CodingKey {
        case smartProtocol
        case vpnProtocol
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        if let vpnProtocol = try container.decodeIfPresent(VpnProtocol.self, forKey: .vpnProtocol) {
            self = .vpnProtocol(vpnProtocol)
        } else {
            self = .smartProtocol
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .smartProtocol:
            try container.encode(true, forKey: .smartProtocol)
        case let .vpnProtocol(vpnProtocol):
            try container.encode(vpnProtocol, forKey: .vpnProtocol)
        }
    }

    public var vpnProtocol: VpnProtocol? {
        guard case let .vpnProtocol(vpnProtocol) = self else {
            return nil
        }
        return vpnProtocol
    }

    public var shouldBeEnabledByDefault: Bool {
        guard self == .smartProtocol else { return false }
#if os(macOS)
        // On MacOS, the user must approve system extensions before Smart Protocol can be used
        return false
#else
        return true
#endif
    }

#if os(macOS)
    public var requiresSystemExtension: Bool {
        guard self != .smartProtocol else {
            return true
        }
        return vpnProtocol?.requiresSystemExtension == true
    }
#endif

    public static let allCases: [ConnectionProtocol] = [.smartProtocol] +
    VpnProtocol.allCases.map(Self.vpnProtocol)
}

#if os(macOS)
extension VpnProtocol {
    public var requiresSystemExtension: Bool {
        switch self {
        case .openVpn, .wireGuard:
            return true
        default:
            return false
        }
    }
}
#endif

extension ConnectionProtocol: LocalizedStringConvertible {

    public var localizedDescription: String {
        switch self {
        case let .vpnProtocol(vpnProtocol):
            return vpnProtocol.localizedDescription
        case .smartProtocol:
            return "Smart"
        }
    }
}

extension VpnProtocol: LocalizedStringConvertible {

    public var localizedDescription: String {
        switch self {
        case .ike: return "IKEv2"
        case .openVpn(let transport):
            return "OpenVPN (\(transport.rawValue.uppercased()))"
        case .wireGuard(let transport):
            switch transport {
            case .udp, .tcp:
                return "WireGuard (\(transport.rawValue.uppercased()))"
            case .tls:
                return "Stealth"
            }
        }
    }
}
