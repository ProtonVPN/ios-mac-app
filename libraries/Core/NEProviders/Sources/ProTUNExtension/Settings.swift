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

        #if os(macOS)
            settings.tunnelOverheadBytes = 80
        #else
            // Path MTU information is unreliable on cellular networks, stick with 1280 to stay at the IPv6 minimum MTU
            // until we have MTU probing support ready
            settings.mtu = 1280
        #endif

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

        // No IPv6 support for now, route IPv6 traffic to a dummy address so it doesn't leak
        let ipv6Settings = NEIPv6Settings(addresses: [.tunnelAddressV6], networkPrefixLengths: [128])
        ipv6Settings.includedRoutes = [
            NEIPv6Route(destinationAddress: .defaultRouteAddressV6, networkPrefixLength: 0),
        ]
        settings.ipv6Settings = ipv6Settings

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

    /// The system requires an interface address, even if we're only adding this to get the traffic sent through our
    /// tunnel through the default route. For now provide an arbitrary LAN IP until we get IPv6 support.
    static let tunnelAddressV6 = "fd00:7076:706e::2"
    static let defaultRouteAddressV6 = "::"

    static let hostMask = "255.255.255.255"
    static let anyMask = "0.0.0.0"
}
