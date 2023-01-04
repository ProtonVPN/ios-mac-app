//
//  WireguardConfig.swift
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

public struct WireguardConfig: Codable, Equatable, DefaultableProperty {
    public let defaultUdpPorts: [Int]
    public let defaultTcpPorts: [Int]
    public let defaultTlsPorts: [Int]

    public var dns: String {
        return "10.2.0.1"
    }
    public var address: String {
        return "10.2.0.2/32"
    }
    public var allowedIPs: String {
        return "0.0.0.0/0"
    }
    public var persistentKeepalive: Int? {
        return 25
    }

    init(defaultUdpPorts: [Int]? = nil, defaultTcpPorts: [Int]? = nil, defaultTlsPorts: [Int]? = nil) {
        self.defaultUdpPorts = defaultUdpPorts ?? [51820]
        self.defaultTcpPorts = defaultTcpPorts ?? [443]
        self.defaultTlsPorts = defaultTlsPorts ?? [443]
    }

    public init() {
        self.init(defaultUdpPorts: nil, defaultTcpPorts: nil, defaultTlsPorts: nil)
    }
}

public struct StoredWireguardConfig: Codable {
    /// Change this if you're changing `StoredWireguardConfig` in a
    /// non-backwards-compatible way, and make sure to update
    /// `tunnelConfigurationFromData`. A more sensible strategy
    /// might be to allow for optional fields for any new values introduced.
    /// (See usage of the @Default property wrapper for an example.)
    static let configurationVersion = Version.v1

    public enum Version: Int {
        case v1 = 1
    }

    let wireguardConfig: WireguardConfig

    let clientPrivateKey: String?
    let serverPublicKey: String?
    let entryServerAddress: String
    let ports: [Int]

    let timestamp: Date

    public func withNewServerPublicKey(_ newServerPublicKey: String?,
                                       andEntryServerAddress newEntryServerAddress: String) -> Self {
        Self(wireguardConfig: wireguardConfig,
             clientPrivateKey: clientPrivateKey,
             serverPublicKey: newServerPublicKey,
             entryServerAddress: newEntryServerAddress,
             ports: ports,
             // update the timestamp since the configuration has changed
             timestamp: Date())
    }
}

/// This is what gets stored in the keychain, to communicate the connection
/// details with the WireGuard network extension.
extension StoredWireguardConfig {
    /// `asWireguardConfiguration` translates this object into a text configuration file
    /// that the `wireguard-go` backend understands.
    public func asWireguardConfiguration() -> String {
        var output = "[Interface]\n"

        if let clientPrivateKey = clientPrivateKey {
            output.append("PrivateKey = \(clientPrivateKey)\n")
        }
        output.append("Address = \(wireguardConfig.address)\n")
        output.append("DNS = \(wireguardConfig.dns)\n")

        output.append("\n[Peer]\n")
        if let serverPublicKey = serverPublicKey {
            output.append("PublicKey = \(serverPublicKey)\n")
        }
        output.append("AllowedIPs = \(wireguardConfig.allowedIPs)\n")

        // VPNAPPL-1447 - find out why the wireguard-go backend is improperly parsing the
        // IPv4 address from the config
        let endpointLine = "Endpoint = \(entryServerAddress):\(ports.first!)\n"
        log.info("WireGuard \(endpointLine)")

        output.append(endpointLine)
        if let persistentKeepalive = wireguardConfig.persistentKeepalive {
            output.append("PersistentKeepalive = \(persistentKeepalive)")
        }

        return output
    }
}
