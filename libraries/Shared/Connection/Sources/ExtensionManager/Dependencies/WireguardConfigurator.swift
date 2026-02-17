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
import DependenciesMacros

import struct Domain.ServerConnectionIntent
import struct Domain.StoredWireguardConfig
import enum Domain.VPNFeatureFlagType
import enum Domain.VpnProtocol
import struct Domain.WireguardConfig
import enum Domain.WireGuardTransport
import protocol Localization.LocalizedStringConvertible

import ConnectionShared

import ConnectionShared
import CoreConnection
import Hermes
import ProtonCoreFeatureFlags

public struct ConnectionConfiguration {
    /// Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)
    public let username: String
    public let wireguardConfig: WireguardConfig
}

public extension ConnectionConfiguration {
    static let testValue = ConnectionConfiguration(username: "mock_username", wireguardConfig: .init())
}

@DependencyClient
public struct ConnectionConfigurationProvider {
    public internal(set) var configuration: @Sendable () -> ConnectionConfiguration = { .testValue }
}

extension ConnectionConfigurationProvider: TestDependencyKey {
    public static let testValue = ConnectionConfigurationProvider { .testValue }
}

extension ConnectionConfigurationProvider: DependencyKey {
    public static var liveValue: ConnectionConfigurationProvider {
        ConnectionConfigurationProvider {
            @Dependency(\.hermesClient) var hermesClient

            let wireguardConfig = WireguardConfig(dns: hermesClient.currentResolvers.map(\.location))
            return ConnectionConfiguration(username: "ProtonVPN", wireguardConfig: wireguardConfig)
        }
    }
}

public extension DependencyValues {
    var connectionConfiguration: ConnectionConfigurationProvider {
        get { self[ConnectionConfigurationProvider.self] }
        set { self[ConnectionConfigurationProvider.self] = newValue }
    }
}

extension ManagerConfigurator {
    private static func providerConfiguration(with connectionIntent: ServerConnectionIntent) throws -> NETunnelProviderProtocol {
        @Dependency(\.bundleIDClient) var bundleIDClient
        let bundleID: String = bundleIDClient.bundleIdentifierForTarget()
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        let server = connectionIntent.server

        guard let entryIP = server.endpoint.entryIp(using: .wireGuard(connectionIntent.tunnelSettings.transport)) else {
            throw WireguardConfiguratorError.entryUnavailableForTransport(connectionIntent.tunnelSettings.transport)
        }
        // Required for old wireguard extension:
        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoint.id

        protocolConfiguration.serverAddress = "" // entryIP. If nil, start fails. Empty string prevents config
        protocolConfiguration.username = nil // Only required for IKEv2.
        protocolConfiguration.wgProtocol = connectionIntent.tunnelSettings.transport.rawValue

        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage

        #if os(iOS)
            protocolConfiguration.includeAllNetworks = connectionIntent.tunnelSettings.features.killSwitch
            protocolConfiguration.excludeLocalNetworks = connectionIntent.tunnelSettings.features.excludeLocalNetworks
        #endif

        // Future: remove this flag and the plumbing that goes all the way to CertificateRefreshRequest.withPublicKey
        // in the NEHelper module and in `parameters` in the CertificateRequest struct in LegacyCommon. (VPNAPPL-2134)
        // Don't remove this FF until we fix the root cause! (VPNAPPL-2766)
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.certificateRefreshForceRenew, reloadValue: true) {
            protocolConfiguration.unleashFeatureFlagShouldForceConflictRefresh = true
        }

        let configData: Data = if FeatureFlagsRepository.shared.isProTUNEnabled {
            try secureProTUNConfigurationData(connectionIntent: connectionIntent)
        } else {
            try secureWGConfigurationData(connectionIntent: connectionIntent, entryIP: entryIP)
        }

        @Dependency(\.tunnelKeychain) var tunnelKeychain
        do {
            let passwordReference = try tunnelKeychain.store(wireguardConfigData: configData)
            protocolConfiguration.passwordReference = passwordReference
            return protocolConfiguration
        } catch TunnelKeychainImplementationError.invalidDataFormatRetrievedFromKeychain {
            throw WireguardConfiguratorError.keychainImplementationError(.invalidDataFormatRetrievedFromKeychain)
        } catch {
            throw WireguardConfiguratorError.keychainError(error)
        }
    }

    static func secureWGConfigurationData(
        connectionIntent: ServerConnectionIntent,
        entryIP: String
    ) throws -> Data {
        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        @Dependency(\.date) var date

        let encoder = JSONEncoder()
        let version: StoredWireguardConfig.Version = .v1
        let storedConfig = StoredWireguardConfig(
            wireguardConfig: connectionConfigurationProvider.configuration().wireguardConfig,
            clientPrivateKey: authenticationStorage.getKeys().privateKey.base64X25519Representation,
            serverPublicKey: connectionIntent.server.endpoint.x25519PublicKey,
            entryServerAddress: entryIP,
            ports: connectionIntent.tunnelSettings.ports,
            timestamp: date.now
        )
        var data = Data([UInt8(version.rawValue)])
        let encodedConfig = try encoder.encode(storedConfig)
        data.append(encodedConfig)
        return data
    }

    static func secureProTUNConfigurationData(connectionIntent: ServerConnectionIntent) throws -> Data {
        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        @Dependency(\.date) var date
        let wgConfig = connectionConfigurationProvider.configuration().wireguardConfig

        let encoder = JSONEncoder()
        // VPNAPPL-3344: accept multiple peers, and provide appropriate ports
        let config = ProTUNConfiguration(
            clientPrivateKey: authenticationStorage.getKeys().privateKey.base64X25519Representation,
            preferredTransport: .udp,
            peers: [
                ProTUNConfiguration.Peer(
                    id: connectionIntent.server.endpoint.id,
                    serverIP: connectionIntent.server.endpoint.entryIp ?? "",
                    serverPublicKey: connectionIntent.server.endpoint.x25519PublicKey ?? "",
                    udpPorts: wgConfig.defaultUdpPorts.map { UInt16($0) },
                    tcpPorts: wgConfig.defaultTcpPorts.map { UInt16($0) },
                    tlsPorts: wgConfig.defaultTlsPorts.map { UInt16($0) },
                    priority: 0
                ),
            ],
            dnsServers: wgConfig.dnsServers ?? []
        )
        return try encoder.encode(config)
    }

    static var wireGuardConfigurator: ManagerConfigurator {
        ManagerConfigurator(
            configure: { manager, operation in
                manager.onDemandRules = [NEOnDemandRuleConnect()]

                switch operation {
                case let .connection(connectionIntent):
                    // also persists the configuration to the keychain.
                    let protocolConfig = try providerConfiguration(with: connectionIntent)
                    manager.vpnProtocolConfiguration = protocolConfig
                    manager.localizedDescription = configurationTitle(for: connectionIntent, isProTUN: protocolConfig.isProTUN)

                    manager.isOnDemandEnabled = true
                    manager.isEnabled = true

                case .disconnection:
                    manager.isOnDemandEnabled = false
                    manager.isEnabled = true
                }
            }
        )
    }

    private static func configurationTitle(for intent: ServerConnectionIntent, isProTUN: Bool) -> String {
        #if DEBUG
            let serverName = intent.server.logical.name
            let transport = intent.tunnelSettings.transport
            let connectionProtocol = isProTUN ? "ProTUN" : VpnProtocol.wireGuard(transport).localizedDescription
            return "\(serverName) - \(connectionProtocol)"
        #else
            return "Proton VPN"
        #endif
    }
}

enum WireguardConfiguratorError: Error {
    case entryUnavailableForTransport(WireGuardTransport)
    case configurationEncodingError(Error)
    case keychainImplementationError(TunnelKeychainImplementationError)
    case keychainError(Error)
}

private extension NETunnelProviderProtocol {
    var isProTUN: Bool {
        providerBundleIdentifier?.contains("ProTUN") ?? false
    }
}
