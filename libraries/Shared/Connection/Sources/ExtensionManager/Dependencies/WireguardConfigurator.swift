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

import enum Domain.WireGuardTransport
import struct Domain.ServerConnectionIntent
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

    private static func configuration(with connectionIntent: ServerConnectionIntent) throws -> NETunnelProviderProtocol {
        // TODO: Provide bundle ID using a Dependency
        let bundleID: String = "ch.protonmail.vpn.WireGuard-tvOS"
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        let server = connectionIntent.server

        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoint.id
        protocolConfiguration.serverAddress = server.endpoint.exitIp
        protocolConfiguration.wgProtocol = connectionIntent.transport.rawValue

        @Dependency(\.connectionConfiguration) var connectionConfiguration
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        @Dependency(\.tunnelKeychain) var tunnelKeychain
        @Dependency(\.date) var date
        protocolConfiguration.username = connectionConfiguration.username

        guard let entryIP = server.endpoint.entryIp(using: .wireGuard(connectionIntent.transport)) else {
            throw WireguardConfiguratorError.entryUnavailableForTransport(connectionIntent.transport)
        }
        let overridePorts = server.endpoint.overridePorts(using: .wireGuard(connectionIntent.transport))

        let encoder = JSONEncoder()
        let version: StoredWireguardConfig.Version = .v1
        let storedConfig = StoredWireguardConfig(
            wireguardConfig: connectionConfiguration.wireguardConfig,
            clientPrivateKey: authenticationStorage.getKeys().privateKey.base64X25519Representation,
            serverPublicKey: server.endpoint.x25519PublicKey,
            entryServerAddress: entryIP,
            ports: overridePorts ?? connectionConfiguration.wireguardConfig.defaultPorts(for: connectionIntent.transport),
            timestamp: date.now
        )

        var configData = Data([UInt8(version.rawValue)])
        do {
            configData.append(try encoder.encode(storedConfig))
        } catch {
            throw WireguardConfiguratorError.configurationEncodingError(error)
        }
        do {
            let passwordReference = try tunnelKeychain.store(wireguardConfigData: configData)
            protocolConfiguration.passwordReference = passwordReference

            return protocolConfiguration
        } catch {
            throw WireguardConfiguratorError.storageError(error)
        }
    }

    static var wireGuardConfigurator: ManagerConfigurator {
        return ManagerConfigurator(
            configure: { manager, operation in
                manager.onDemandRules = [NEOnDemandRuleConnect()]

                switch operation {
                case .connection(let connectionIntent):
                    manager.vpnProtocolConfiguration = try configuration(with: connectionIntent)
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

enum WireguardConfiguratorError: Error {
    case entryUnavailableForTransport(WireGuardTransport)
    case configurationEncodingError(Error)
    case storageError(Error)
}
