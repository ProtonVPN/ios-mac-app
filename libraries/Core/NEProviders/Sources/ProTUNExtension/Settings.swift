//
//  Created on 07/01/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
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

import Hermes
import NetworkExtension
import os

enum SettingsGenerator {
    static func settings(excludingRoutes excludedRoutes: [String], dnsServers: [String]) -> NETunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: .ipv4Loopback)

        settings.tunnelOverheadBytes = 80

        settings.dnsSettings = dnsSettings(from: dnsServers)
        settings.dnsSettings?.matchDomains = [""]

        let ipv4Settings = NEIPv4Settings(addresses: [.tunnelAddress], subnetMasks: [.hostMask])
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: .localAgentAddress, subnetMask: .hostMask),
            NEIPv4Route(destinationAddress: .tunnelAddress, subnetMask: .hostMask),
            NEIPv4Route(destinationAddress: .defaultRouteAddress, subnetMask: .anyMask),
        ]
        ipv4Settings.excludedRoutes = excludedRoutes.map { NEIPv4Route(destinationAddress: $0, subnetMask: .hostMask) }

        settings.ipv4Settings = ipv4Settings

        return settings
    }

    private static func dnsSettings(from resolverLocations: [String] = [HermesResolver.proton.location]) -> NEDNSSettings {
        let dnsServers = resolverLocations.compactMap(DNSResolver.init).sorted()

        // When using DoH/DoT, it seems we can only set one serverName/serverURL
        // So for now, we would expect that DNS resolvers are sorted by transport so TLS/HTTPS related entries would be first.
        let firstElement = dnsServers.first ?? .proton
        switch firstElement.transport {
        case .tls:
            let dnsSettings = NEDNSOverTLSSettings()
            dnsSettings.serverName = firstElement.stringRepresentation
            return dnsSettings
        case .https:
            let dnsSettings = NEDNSOverHTTPSSettings()
            dnsSettings.serverURL = URL(string: firstElement.stringRepresentation)
            return dnsSettings
        case .classic:
            return NEDNSSettings(servers: dnsServers.map(\.stringRepresentation))
        }
    }
}

private extension String {
    static let ipv4Loopback: String = "127.0.0.1"

    static let localAgentAddress = "10.2.0.1"
    static let tunnelAddress = "10.2.0.2"
    static let defaultRouteAddress = "0.0.0.0"

    static let hostMask = "255.255.255.255"
    static let anyMask = "0.0.0.0"
}
