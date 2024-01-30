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

public struct ProtocolSupport: OptionSet, Codable {

    public let rawValue: Int

    public static let ikev2 = ProtocolSupport(bitPosition: VpnProtocol.ike.protocolSupportBitPosition)
    public static let wireGuardUDP = ProtocolSupport(bitPosition: VpnProtocol.wireGuard(.udp).protocolSupportBitPosition)
    public static let wireGuardTCP = ProtocolSupport(bitPosition: VpnProtocol.wireGuard(.tcp).protocolSupportBitPosition)
    public static let wireGuardTLS = ProtocolSupport(bitPosition: VpnProtocol.wireGuard(.tls).protocolSupportBitPosition)
    public static let openVPNUDP = ProtocolSupport(bitPosition: VpnProtocol.openVpn(.udp).protocolSupportBitPosition)
    public static let openVPNTCP = ProtocolSupport(bitPosition: VpnProtocol.openVpn(.tcp).protocolSupportBitPosition)

    public static let zero = ProtocolSupport([])
    public static let all = ProtocolSupport([.ikev2, .wireGuardUDP, .wireGuardTCP, .wireGuardTLS, .openVPNUDP, .openVPNTCP])

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(vpnProtocols: [VpnProtocol]) {
        self.rawValue = vpnProtocols.reduce(.zero) { result, nextValue in
            result + ProtocolSupport(bitPosition: nextValue.protocolSupportBitPosition)
        }.rawValue
    }
}

extension VpnProtocol {
    fileprivate var protocolSupportBitPosition: Int {
        switch self {
        case .ike:
            return 0
        case .wireGuard(.udp):
            return 1
        case .wireGuard(.tcp):
            return 2
        case .wireGuard(.tls):
            return 3
        case .openVpn(.udp):
            return 4
        case .openVpn(.tcp):
            return 5
        }
    }

    public var protocolSupport: ProtocolSupport {
        ProtocolSupport(bitPosition: self.protocolSupportBitPosition)
    }
}
