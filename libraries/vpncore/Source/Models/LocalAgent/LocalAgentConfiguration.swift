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

public struct LocalAgentConfiguration {
    let hostname: String
    let features: VPNConnectionFeatures

    init(hostname: String, netshield: NetShieldType, vpnAccelerator: Bool, bouncing: String?) {
        self.hostname = hostname
        self.features = VPNConnectionFeatures(netshield: netshield, vpnAccelerator: vpnAccelerator, bouncing: bouncing)
    }
}

extension LocalAgentConfiguration {
    init(configuration: VpnManagerConfiguration) {
        self.init(hostname: configuration.hostname, netshield: configuration.netShield, vpnAccelerator: configuration.vpnAccelerator, bouncing: configuration.bouncing)
    }

    init?(propertiesManager: PropertiesManagerProtocol, vpnProtocol: VpnProtocol?) {
        guard let connectionConfiguration = propertiesManager.currentConnectionConfiguration() else {
            return nil
        }

        self.init(hostname: connectionConfiguration.serverIp.domain,
                  netshield: propertiesManager.netShieldType ?? .off,
                  vpnAccelerator: !propertiesManager.featureFlags.vpnAccelerator || propertiesManager.vpnAcceleratorEnabled,
                  bouncing: connectionConfiguration.serverIp.label)
    }
}

// MARK: - LocalAgentConfiguration.Features

extension VPNConnectionFeatures {
    
    init?(propertiesManager: PropertiesManagerProtocol, vpnProtocol: VpnProtocol?) {
        guard let connectionConfiguration = propertiesManager.currentConnectionConfiguration() else {
            return nil
        }

        self.init(netshield: propertiesManager.netShieldType ?? .off,
                  vpnAccelerator: !propertiesManager.featureFlags.vpnAccelerator || propertiesManager.vpnAcceleratorEnabled,
                  bouncing: connectionConfiguration.serverIp.label)
    }
}

// MARK: - PropertiesManagerProtocol

private extension PropertiesManagerProtocol {
    
    func currentConnectionConfiguration() -> ConnectionConfiguration? {
        let configuration: ConnectionConfiguration?
        switch vpnProtocol {
        case .ike:
            configuration = self.lastIkeConnection
        case .openVpn:
            configuration = self.lastOpenVpnConnection
        case .wireGuard:
            configuration = self.lastWireguardConnection
        }
        return configuration
    }
}
