//
//  SmartProtocol+Priority.swift
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

import Domain
import Foundation
import VPNShared

/// The protocols Smart Protocol chooses between. Only the WireGuard transports are included, so Smart Protocol never
/// connects with IKEv2, which infra is retiring.
enum SmartProtocolProtocol: CaseIterable {
    case wireguardUdp
    case wireguardTcp
    case wireguardTls

    var transport: WireGuardTransport {
        switch self {
        case .wireguardUdp:
            .udp
        case .wireguardTcp:
            .tcp
        case .wireguardTls:
            .tls
        }
    }

    var vpnProtocol: VpnProtocol {
        .wireGuard(transport)
    }

    /// Smart Protocol prefers lower values, both among the protocols that pass their checks and when falling back.
    var priority: Int {
        switch self {
        case .wireguardUdp:
            0
        case .wireguardTls:
            1
        case .wireguardTcp:
            2
        }
    }
}
