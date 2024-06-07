//
//  Created on 31/05/2024.
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

import class NetworkExtension.NEOnDemandRuleConnect
import class NetworkExtension.NETunnelProviderProtocol

import Dependencies

import struct Domain.VPNServer

extension ManagerConfigurator {

    private static func configuration(forConnectionTo server: VPNServer) -> NETunnelProviderProtocol {
        // TODO: Provide bundle ID using a Dependency
        let bundleID: String = "ch.protonmail.vpn.WireGuard-tvOS"
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoints.first?.id ?? "nil"
        protocolConfiguration.serverAddress = server.endpoints.first?.entryIp ?? "nil"
        // TODO: Set transport type and other required properties

        return protocolConfiguration
    }

    static var wireGuardConfigurator: ManagerConfigurator {
        return ManagerConfigurator(
            configure: { manager, operation in
                manager.onDemandRules = [NEOnDemandRuleConnect()]

                switch operation {
                case .connection(let server):
                    manager.vpnProtocolConfiguration = configuration(forConnectionTo: server)
                    manager.isOnDemandEnabled = true
                    manager.isEnabled = true

                case .disconnection:
                    manager.isOnDemandEnabled = false
                    manager.isEnabled = false
                }
            }
        )
    }
}
