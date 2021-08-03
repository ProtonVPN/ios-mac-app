//
//  SmartProtocol+Priority.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

enum SmartProtocolProtocol {
    case ikev2
    case openVpnUdp
    case openVpnTcp
    case wireguard

    var vpnProtocol: VpnProtocol {
        switch self {
        case .ikev2:
            return .ike
        case .openVpnUdp:
            return .openVpn(.udp)
        case .openVpnTcp:
            return .openVpn(.tcp)
        case .wireguard:
            return .wireGuard
        }
    }

    var priority: Int {
        #if os(iOS)
        switch self {
        case .wireguard:
            return 0
        case .openVpnUdp:
            return 1
        case .openVpnTcp:
            return 2
        case .ikev2:
            return 3
        }
        #else
        switch self {
        case .wireguard:
            return 0
        case .ikev2:
            return 1
        case .openVpnUdp:
            return 2
        case .openVpnTcp:
            return 3
        }
        #endif
    }
}
