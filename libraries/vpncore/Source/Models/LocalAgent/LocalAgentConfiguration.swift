//
//  LocalAgentConfiguration.swift
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

struct LocalAgentConfiguration {
    let hostname: String
    let netshield: NetShieldType
    let vpnAccelerator: Bool
    let bouncing: String?

    init(hostname: String, netshield: NetShieldType, vpnAccelerator: Bool, bouncing: String?) {
        self.hostname = hostname
        self.netshield = netshield
        self.vpnAccelerator = vpnAccelerator
        self.bouncing = bouncing
    }
}

extension LocalAgentConfiguration {
    init(configuration: VpnManagerConfiguration) {
        self.init(hostname: configuration.hostname, netshield: configuration.netShield, vpnAccelerator: configuration.vpnAccelerator, bouncing: configuration.bouncing)
    }

    init?(propertiesManager: PropertiesManagerProtocol, vpnProtocol: VpnProtocol?) {
        let configuration: ConnectionConfiguration?
        switch vpnProtocol {
        case .ike:
            configuration = propertiesManager.lastIkeConnection
        case .openVpn:
            configuration = propertiesManager.lastOpenVpnConnection
        case .wireGuard:
            configuration = propertiesManager.lastWireguardConnection
        case nil:
            configuration = nil
        }

        guard let connectionConfiguration = configuration else {
            return nil
        }

        self.init(hostname: connectionConfiguration.serverIp.domain, netshield: propertiesManager.netShieldType ?? .off, vpnAccelerator: !propertiesManager.featureFlags.vpnAccelerator || propertiesManager.vpnAcceleratorEnabled, bouncing: connectionConfiguration.serverIp.label)
    }
}
