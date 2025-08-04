//
//  Created on 04/08/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import NATPMPUI

extension VpnManager {
    func startNATPortMappingService() {
        guard let gatewayAddress = getVPNGatewayAddress() else {
            log.error("Cannot start NAT port mapping - unable to determine gateway address", category: .connection)
            return
        }
        @Dependency(\.natPortMappingService) var natPortMappingService
        // Start your service
        natPortMappingService.startPortMapping(gatewayAddress: gatewayAddress)
        log.info("NAT port mapping service started", category: .connection)
    }

    func stopNATPortMappingService() {
        @Dependency(\.natPortMappingService) var natPortMappingService
        Task {
            await natPortMappingService.cancelPortMapping()
            log.info("NAT port mapping service stopped", category: .connection)
        }
    }

    // MARK: - Private

    private func getVPNGatewayAddress() -> String? {
        guard let currentVpnProtocol else {
            log.error("Cannot determine gateway address - no current VPN protocol", category: .connection)
            return nil
        }

        switch currentVpnProtocol {
        case .ike:
            return "10.1.0.1" // IKEv2 gateway
        case .wireGuard:
            return getWireGuardConfiguredGateway()
        case .openVpn:
            // OpenVPN is deprecated, but if needed, could use 10.1.0.1
            return "10.1.0.1"
        }
    }

    private func getWireGuardConfiguredGateway() -> String? {
        guard let currentVpnProtocol,
              case .wireGuard = currentVpnProtocol else {
            return getVPNGatewayAddress()
        }

        // Access the stored WireGuard config
        @Dependency(\.propertiesManager) var propertiesManager

        let wgConfig = propertiesManager.wireguardConfig
        // Extract DNS servers (which act as gateways)
        let dnsServers = wgConfig.dnsServers ?? ["10.2.0.1"]
        let gateway = dnsServers.first ?? "10.2.0.1"

        log.info("Using WireGuard DNS/gateway: \(gateway)", category: .connection)
        return gateway
    }
}
