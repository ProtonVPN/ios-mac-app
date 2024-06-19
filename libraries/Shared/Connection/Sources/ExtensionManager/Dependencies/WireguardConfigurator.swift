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

import struct Domain.Server
import struct ConnectionFoundations.WireguardConfig
import struct ConnectionFoundations.StoredWireguardConfig

public struct ConnectionConfiguration {

    /// Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)
    public let username: String
    public let wireguardConfig: WireguardConfig


}
public enum ConnectionConfigurationKey: DependencyKey {

    public static var liveValue: ConnectionConfiguration {
        return .init(
            username: "mockman",
            wireguardConfig: .init()
        )
    }
}

extension DependencyValues {
    var connectionConfiguration: ConnectionConfiguration {
        get { self[ConnectionConfigurationKey.self] }
        set { self[ConnectionConfigurationKey.self] = newValue }
    }
}


extension ManagerConfigurator {

    private static func configuration(forConnectionTo server: Server) -> NETunnelProviderProtocol {
        // TODO: Provide bundle ID using a Dependency
        let bundleID: String = "ch.protonmail.vpn.WireGuard-tvOS"
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoint.id
        protocolConfiguration.serverAddress = server.endpoint.entryIp ?? server.endpoint.exitIp
        protocolConfiguration.wgProtocol = "udp" // TODO: specify transport type

        @Dependency(\.connectionConfiguration) var connectionConfiguration
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        authenticationStorage.deleteKeys()
        @Dependency(\.tunnelKeychain) var tunnelKeychain
        @Dependency(\.date) var date
        protocolConfiguration.username = connectionConfiguration.username

        // This should be done outside connection and passed in
        // let entryIp = serverIp.entryIp(using: vpnProtocol) ?? serverIp.entryIp

        let encoder = JSONEncoder()
        let version: StoredWireguardConfig.Version = .v1
        let storedConfig = StoredWireguardConfig(
            wireguardConfig: connectionConfiguration.wireguardConfig,
            clientPrivateKey: authenticationStorage.getKeys().privateKey.base64X25519Representation,
            serverPublicKey: server.endpoint.x25519PublicKey,
            entryServerAddress: server.endpoint.entryIp ?? server.endpoint.exitIp, // TODO: select entry IP according to protocol
            ports: connectionConfiguration.wireguardConfig.defaultUdpPorts, // TODO: select ports
            timestamp: date.now
        )

        var configData = Data([UInt8(version.rawValue)])
        configData.append(try! encoder.encode(storedConfig)) // TODO: error handling
        let passwordReference = try! tunnelKeychain.storeWireguardConfig(configData)
        protocolConfiguration.passwordReference = passwordReference

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
