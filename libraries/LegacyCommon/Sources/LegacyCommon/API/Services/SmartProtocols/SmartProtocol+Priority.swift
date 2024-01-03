//
//  SmartProtocolProtocol+Priority.swift
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

enum SmartProtocolProtocol {
    case ikev2
    case openVpnUdp
    case openVpnTcp
    case wireguardUdp
    case wireguardTcp
    case wireguardTls

    var vpnProtocol: VpnProtocol {
        switch self {
        case .ikev2:
            return .ike
        case .openVpnUdp:
            return .openVpn(.udp)
        case .openVpnTcp:
            return .openVpn(.tcp)
        case .wireguardUdp:
            return .wireGuard(.udp)
        case .wireguardTcp:
            return .wireGuard(.tcp)
        case .wireguardTls:
            return .wireGuard(.tls)
        }
    }

    var priority: Int {
        #if os(iOS)
        switch self {
        case .wireguardUdp:
            return 0
        case .openVpnUdp:
            return 1
        case .openVpnTcp:
            return 2
        case .wireguardTls:
            return 3
        case .wireguardTcp:
            return 4
        case .ikev2:
            return 5
        }
        #else
        switch self {
        case .wireguardUdp:
            return 0
        case .ikev2:
            return 1
        case .openVpnUdp:
            return 2
        case .openVpnTcp:
            return 3
        case .wireguardTls:
            return 4
        case .wireguardTcp:
            return 5
        }
        #endif
    }
}
