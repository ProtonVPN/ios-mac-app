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

import ConnectionShared
import CoreConnection
import Dependencies
import DependenciesMacros
import struct Domain.ServerConnectionIntent
import struct Domain.StoredWireguardConfig
import enum Domain.VPNFeatureFlagType
import enum Domain.VpnProtocol
import struct Domain.WireguardConfig
import enum Domain.WireGuardTransport
import Foundation
import Hermes
import protocol Localization.LocalizedStringConvertible
import NEHelper
import NetworkExtension
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
        let bundleID: String = bundleIDClient.bundleIdentifier(connectionIntent.tunnelProtocol)
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        let server = connectionIntent.server

        guard case let .wireGuard(wgSettings) = connectionIntent.protocolConfiguration else {
            throw WireguardConfiguratorError.incorrectProtocolConfiguration
        }

        guard let entryIP = server.endpoint.entryIp(using: .wireGuard(wgSettings.transport)) else {
            throw WireguardConfiguratorError.entryUnavailableForTransport(wgSettings.transport)
        }
        // Required for old wireguard extension:
        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoint.id

        protocolConfiguration.serverAddress = "" // entryIP. If nil, start fails. Empty string prevents config
        protocolConfiguration.username = nil // Only required for IKEv2.
        protocolConfiguration.wgProtocol = wgSettings.transport.rawValue

        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage

        #if os(iOS)
            protocolConfiguration.includeAllNetworks = wgSettings.features.killSwitch
            protocolConfiguration.excludeLocalNetworks = wgSettings.features.excludeLocalNetworks
        #endif

        // Future: remove this flag and the plumbing that goes all the way to CertificateRefreshRequest.withPublicKey
        // in the NEHelper module and in `parameters` in the CertificateRequest struct in LegacyCommon. (VPNAPPL-2134)
        // Don't remove this FF until we fix the root cause! (VPNAPPL-2766)
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.certificateRefreshForceRenew, reloadValue: true) {
            protocolConfiguration.unleashFeatureFlagShouldForceConflictRefresh = true
        }

        let configData: Data? = try secureConfigurationData(intent: connectionIntent, entryIP: entryIP)
        guard let configData else {
            return protocolConfiguration
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

    static func secureConfigurationData(intent: ServerConnectionIntent, entryIP: String) throws -> Data? {
        guard case let .wireGuard(settings) = intent.protocolConfiguration else {
            // We don't need to store any additional data for IKE
            return nil
        }
        switch settings.backend {
        case .go:
            return try secureWGConfigurationData(connectionIntent: intent, entryIP: entryIP)
        case .proTUN:
            return try secureProTUNConfigurationData(connectionIntent: intent)
        }
    }

    static func secureWGConfigurationData(
        connectionIntent: ServerConnectionIntent,
        entryIP: String
    ) throws -> Data {
        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        @Dependency(\.date) var date

        guard case let .wireGuard(wgSettings) = connectionIntent.protocolConfiguration else {
            throw WireguardConfiguratorError.incorrectProtocolConfiguration
        }

        let encoder = JSONEncoder()
        let version: StoredWireguardConfig.Version = .v1
        let storedConfig = StoredWireguardConfig(
            wireguardConfig: connectionConfigurationProvider.configuration().wireguardConfig,
            clientPrivateKey: authenticationStorage.getKeys().privateKey.base64X25519Representation,
            serverPublicKey: connectionIntent.server.endpoint.x25519PublicKey,
            entryServerAddress: entryIP,
            ports: wgSettings.ports,
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
                    switch connectionIntent.protocolConfiguration {
                    case .ike:
                        manager.protocolConfiguration = ikeConfiguration(with: connectionIntent)
                    case .wireGuard:
                        // also persists the configuration to the keychain.
                        let protocolConfig = try providerConfiguration(with: connectionIntent)
                        manager.vpnProtocolConfiguration = protocolConfig
                    }
                    manager.localizedDescription = configurationTitle(for: connectionIntent)

                    manager.isOnDemandEnabled = true
                    manager.isEnabled = true

                case .disconnection:
                    manager.isOnDemandEnabled = false
                    manager.isEnabled = true
                }
            }
        )
    }

    private static func configurationTitle(for intent: ServerConnectionIntent) -> String {
        #if DEBUG
            let serverName = intent.server.logical.name
            let connectionProtocol: String = switch intent.protocolConfiguration {
            case .ike:
                "IKEv2"
            case let .wireGuard(wgSettings):
                switch wgSettings.backend {
                case .go:
                    VpnProtocol.wireGuard(wgSettings.transport).localizedDescription
                case .proTUN:
                    "ProTUN"
                }
            }
            return "\(serverName) - \(connectionProtocol)"
        #else
            return "Proton VPN"
        #endif
    }

    private static func ikeConfiguration(with intent: ServerConnectionIntent) -> NEVPNProtocolIKEv2 {
        let config = NEVPNProtocolIKEv2()

        // VPNAPPL-3466: Handle keychain errors during mac IKE integration
        @Dependency(\.vpnKeychain) var keychain
        let vpnCredentials = try! keychain.fetch()
        let passwordReference = try! keychain.fetchOpenVpnPassword()
        let username = vpnCredentials.name

        // VPNAPPL-3466: Encode the rest of the features in the username
        config.username = username + "+\(intent.server.endpoint.id)"
        config.passwordReference = passwordReference

        config.localIdentifier = username // makes it easier to troubleshoot connection issues server-side
        config.remoteIdentifier = intent.server.logical.domain
        config.serverAddress = intent.server.endpoint.entryIp
        config.useExtendedAuthentication = true
        config.disconnectOnSleep = false
        config.enablePFS = false
        config.deadPeerDetectionRate = .high

        #if os(macOS)
            config.authenticationMethod = .certificate
            config.serverCertificateIssuerCommonName = "ProtonVPN Root CA"
        #endif

        config.disableMOBIKE = false
        config.disableRedirect = false
        config.enableRevocationCheck = false
        config.useConfigurationAttributeInternalIPSubnet = false

        config.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
        config.ikeSecurityAssociationParameters.integrityAlgorithm = .SHA384
        config.ikeSecurityAssociationParameters.diffieHellmanGroup = .group20 // .group15
        config.ikeSecurityAssociationParameters.lifetimeMinutes = 480

        config.childSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256
        config.childSecurityAssociationParameters.integrityAlgorithm = .SHA256
        config.childSecurityAssociationParameters.diffieHellmanGroup = .group20
        config.childSecurityAssociationParameters.lifetimeMinutes = 60

        return config
    }
}

enum WireguardConfiguratorError: Error {
    case entryUnavailableForTransport(WireGuardTransport)
    case incorrectProtocolConfiguration
    case configurationEncodingError(Error)
    case keychainImplementationError(TunnelKeychainImplementationError)
    case keychainError(Error)
}

private extension NETunnelProviderProtocol {
    var isProTUN: Bool {
        providerBundleIdentifier?.contains("ProTUN") ?? false
    }
}
