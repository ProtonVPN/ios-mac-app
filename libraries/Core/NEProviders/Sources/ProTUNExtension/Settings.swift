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

import NetworkExtension

enum SettingsGenerator {
    private static let ipv4Loopback: String = "127.0.0.1"
    private static let protonDNSServer: String = "10.2.0.1"

    // Very trivial settings generator for now
    // It should:
    // * remove hardcoded values
    // * handle custom DNS
    // * handle ipv6?
    // * ...
    static func settings(excludingRoute: String) -> NETunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: Self.ipv4Loopback)

        let dnsSettings = NEDNSSettings(servers: [Self.protonDNSServer])
        dnsSettings.matchDomains = [""]

        settings.dnsSettings = dnsSettings

        let ipv4Settings = NEIPv4Settings(
            addresses: ["10.2.0.2"],
            subnetMasks: ["255.255.255.255"]
        )
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: "10.2.0.2", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0"),
        ]
        ipv4Settings.excludedRoutes = [NEIPv4Route(destinationAddress: excludingRoute, subnetMask: "255.255.255.255")]

        settings.ipv4Settings = ipv4Settings
        return settings
    }
}
