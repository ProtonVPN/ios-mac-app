//
//  Created on 06/01/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Ergonomics

public struct ProtocolSupport: OptionSet, Sendable, Codable, CaseIterable, CustomStringConvertible {
    public static let allCases: [ProtocolSupport] = [.ikev2, .wireGuardUDP, .wireGuardTCP, .wireGuardTLS, .openVPNUDP, .openVPNTCP]

    public let rawValue: Int

    public static let ikev2 = ProtocolSupport(bitPosition: VpnProtocol.ike.protocolSupportBitPosition)
    public static let wireGuardUDP = ProtocolSupport(bitPosition: VpnProtocol.wireGuard(.udp).protocolSupportBitPosition)
    public static let wireGuardTCP = ProtocolSupport(bitPosition: VpnProtocol.wireGuard(.tcp).protocolSupportBitPosition)
    public static let wireGuardTLS = ProtocolSupport(bitPosition: VpnProtocol.wireGuard(.tls).protocolSupportBitPosition)
    public static let openVPNUDP = ProtocolSupport(bitPosition: VpnProtocol.openVpn(.udp).protocolSupportBitPosition)
    public static let openVPNTCP = ProtocolSupport(bitPosition: VpnProtocol.openVpn(.tcp).protocolSupportBitPosition)

    public static let zero = ProtocolSupport([])
    public static let all = ProtocolSupport(allCases)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(vpnProtocols: [VpnProtocol]) {
        self.rawValue = vpnProtocols.reduce(.zero) { result, nextValue in
            result + ProtocolSupport(bitPosition: nextValue.protocolSupportBitPosition)
        }.rawValue
    }

    public var description: String {
        var elements: [VpnProtocol] = []
        for supportedProtocol in Self.allCases where contains(supportedProtocol) {
            guard let element = VpnProtocol(element: supportedProtocol) else { continue }
            elements.append(element)
        }
        return elements.map(\.apiDescription).joined(separator: ", ")
    }
}

extension VpnProtocol {
    fileprivate var protocolSupportBitPosition: Int {
        switch self {
        case .ike:
            0
        case .wireGuard(.udp):
            1
        case .wireGuard(.tcp):
            2
        case .wireGuard(.tls):
            3
        case .openVpn(.udp):
            4
        case .openVpn(.tcp):
            5
        }
    }

    fileprivate init?(element: ProtocolSupport) {
        switch element {
        case .ikev2:
            self = .ike
        case .openVPNUDP:
            self = .openVpn(.udp)
        case .openVPNTCP:
            self = .openVpn(.tcp)
        case .wireGuardUDP:
            self = .wireGuard(.udp)
        case .wireGuardTCP:
            self = .wireGuard(.tcp)
        case .wireGuardTLS:
            self = .wireGuard(.tls)
        default:
            return nil
        }
    }

    public var protocolSupport: ProtocolSupport {
        ProtocolSupport(bitPosition: protocolSupportBitPosition)
    }
}
