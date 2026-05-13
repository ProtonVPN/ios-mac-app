//
//  Created on 07/05/2026 by Chris Janusiewicz.
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

import Foundation
import NetworkExtension

import struct Domain.StoredWireguardConfig
import VPNCoreCommon
import struct VPNCoreTypes.ProTUNConfiguration
import enum VPNCoreTypes.WireGuardTransport

public extension ProTUNConfigurationCoder {
    /// One-time migration path: read the legacy WireGuard `StoredWireguardConfig` that we
    /// previously persisted for the WireGuard Go extension via `TunnelKeychainImplementation`
    /// (since we needed to securely transfer the app-generated private key), and translate it
    /// into a `ProTUNConfiguration` so an existing tunnel established pre-ProTUN keeps running
    /// until the app rewrites the configuration through the new provider-configuration path.
    static func legacyDecode(
        from protocolConfiguration: NEVPNProtocol
    ) throws(CodingError) -> ProTUNConfiguration {
        let configurationData: Data?
        do {
            configurationData = try TunnelKeychainImplementation().loadWireguardConfig()
        } catch {
            throw .codingFailed(error)
        }

        guard let configurationData else {
            throw .proTUNConfigurationMissing
        }

        let storedConfig: StoredWireguardConfig
        do {
            storedConfig = try StoredWireguardConfig.decodeLegacyKeychainData(configurationData)
        } catch {
            throw .codingFailed(error)
        }

        do {
            return try ProTUNConfiguration(
                legacy: storedConfig,
                tunnelProviderProtocol: protocolConfiguration as? NETunnelProviderProtocol
            )
        } catch {
            throw .codingFailed(error)
        }
    }

    enum LegacyMigrationError: Error {
        case serverPublicKeyMissing
        case peerIdMissing
    }
}

private extension ProTUNConfiguration {
    init(
        legacy stored: StoredWireguardConfig,
        tunnelProviderProtocol: NETunnelProviderProtocol?
    ) throws(ProTUNConfigurationCoder.LegacyMigrationError) {
        guard let serverPublicKey = stored.serverPublicKey else {
            throw .serverPublicKeyMissing
        }
        let wgConfig = stored.wireguardConfig
        let providerConfiguration = tunnelProviderProtocol?.providerConfiguration
        guard let peerId = providerConfiguration?["PVPNServerIpID"] as? String else {
            throw .peerIdMissing
        }
        let preferredTransport = WireGuardTransport(
            legacyWgProtocol: providerConfiguration?["wg-protocol"] as? String
        )

        self.init(
            preferredTransport: preferredTransport,
            peers: [
                Peer(
                    id: peerId,
                    serverIP: stored.entryServerAddress,
                    serverPublicKey: serverPublicKey,
                    udpPorts: wgConfig.defaultUdpPorts.map { UInt16($0) },
                    tcpPorts: wgConfig.defaultTcpPorts.map { UInt16($0) },
                    tlsPorts: wgConfig.defaultTlsPorts.map { UInt16($0) },
                    priority: 0
                ),
            ],
            dnsServers: wgConfig.dnsServers ?? []
        )
    }
}

private extension WireGuardTransport {
    init(legacyWgProtocol: String?) {
        switch legacyWgProtocol {
        case "tcp": self = .tcp
        case "tls": self = .tls
        default: self = .udp
        }
    }
}
