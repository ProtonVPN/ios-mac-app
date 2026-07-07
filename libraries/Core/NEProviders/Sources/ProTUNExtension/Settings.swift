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
    private static let ipv4Loopback: String = "127.0.0.1"

    static func settings(excludingRoute: String?, dnsServers: [String]) -> NETunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: Self.ipv4Loopback)

        settings.dnsSettings = dnsSettings(from: dnsServers)
        settings.dnsSettings?.matchDomains = [""]

        let ipv4Settings = NEIPv4Settings(
            addresses: ["10.2.0.2"],
            subnetMasks: ["255.255.255.255"]
        )
        ipv4Settings.includedRoutes = [
            NEIPv4Route.localAgent,
            NEIPv4Route(destinationAddress: "10.2.0.2", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0"),
        ]
        if let excludingRoute {
            ipv4Settings.excludedRoutes = [NEIPv4Route(destinationAddress: excludingRoute, subnetMask: "255.255.255.255")]
        }

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

extension NEIPv4Route {
    nonisolated(unsafe) static let localAgent: NEIPv4Route = .init(destinationAddress: "10.2.0.1", subnetMask: "255.255.255.255")
}
