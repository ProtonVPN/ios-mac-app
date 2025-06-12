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
            vpnProtocol.localizedDescription
        case .smartProtocol:
            "Smart"
        }
    }
}

extension VpnProtocol: LocalizedStringConvertible {
    public var localizedDescription: String {
        var string: String
        switch self {
        case .ike:
            string = Localizable.ikev2
        case let .openVpn(transportProtocol):
            string = Localizable.openvpn
            switch transportProtocol {
            case .tcp:
                string += " (\(Localizable.tcp))"
            case .udp:
                string += " (\(Localizable.udp))"
            }
        case let .wireGuard(transportProtocol):
            string = Localizable.wireguard
            switch transportProtocol {
            case .udp:
                string += "" // (\(Localizable.udp))
            case .tcp:
                string += " (\(Localizable.tcp))"
            case .tls:
                string = Localizable.wireguardTls
            }
        }

        return string
    }
}
