//
//  Created on 28/02/2024.
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
import Domain
import Strings

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
