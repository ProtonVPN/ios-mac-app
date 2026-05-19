//
//  VpnFeatureChangeState.swift
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

import Connection
import Domain
import Foundation
import Settings
import VPNAppCore
import VPNShared

public typealias VpnFeatureChangeState = FeatureChangeAvailability

public extension VpnFeatureChangeState {
    init(connectionState: ConnectionState, vpnConnectionStatus: VPNConnectionStatus) {
        let vpnProtocol = vpnConnectionStatus.mergedVpnProtocol(using: connectionState)
        let isConnected = vpnConnectionStatus.isConnected(using: connectionState)
        let isConnecting = if case .connecting = connectionState {
            true
        } else if case .connecting = vpnConnectionStatus {
            true
        } else {
            false
        }

        if isConnected, vpnProtocol?.authenticationType == .certificate {
            self = .withConnectionUpdate
        } else if isConnected || isConnecting {
            self = .withReconnect
        } else {
            self = .immediate
        }
    }
}
