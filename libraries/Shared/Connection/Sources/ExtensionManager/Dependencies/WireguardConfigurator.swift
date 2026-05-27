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
import Domain
import Foundation
import Hermes
import Localization
import NEHelper
import NetworkExtension
import ProtonCoreFeatureFlags
import VPNCoreCommon
import VPNCoreTypes

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
    private static func providerConfiguration(with connectionIntent: ServerConnectionIntent) async throws -> NETunnelProviderProtocol {
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
        if case .proTUN = wgSettings.backend {
            try encodeProTUNConfiguration(connectionIntent: connectionIntent, on: protocolConfiguration)
        }
        guard let configData else {
            return protocolConfiguration
        }
        @Dependency(\.tunnelKeychain) var tunnelKeychain
        do {
            #if os(macOS)
                // `pushConfig` returns `false` on any XPC failure (no remote object, failed
                // connection, etc.). Surfacing the failure as a `WireguardConfiguratorError`
                // means callers fail fast with an actionable error instead of producing a
                // `NETunnelProviderProtocol` with no password reference that silently fails
                // to start the tunnel.
                @Dependency(\.wireguardExtensionConfigClient) var extensionConfigClient
                let succeeded = await extensionConfigClient.pushConfig(configData)
                guard succeeded else {
                    throw WireguardConfiguratorError.configurationXPCWriteFailed
                }
            #else
                let passwordReference = try tunnelKeychain.store(wireguardConfigData: configData)
                protocolConfiguration.passwordReference = passwordReference
            #endif
            return protocolConfiguration
        } catch TunnelKeychainImplementationError.invalidDataFormatRetrievedFromKeychain {
            throw WireguardConfiguratorError.keychainImplementationError(.invalidDataFormatRetrievedFromKeychain)
        } catch let error as WireguardConfiguratorError {
            throw error
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
            // We're able to encode the whole configuration into the `NETunnelProviderProtocol` for ProTUN
            return nil
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

    static func encodeProTUNConfiguration(connectionIntent: ServerConnectionIntent, on protocolConfiguration: NETunnelProviderProtocol) throws {
        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        @Dependency(\.date) var date
        let wgConfig = connectionConfigurationProvider.configuration().wireguardConfig

        let privateKey = authenticationStorage.getKeys().privateKey.base64X25519Representation
        // VPNAPPL-3344: accept multiple peers, and provide appropriate ports
        let config = ProTUNConfiguration(
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
        try ProTUNConfigurationCoder.encode(configuration: config, to: protocolConfiguration)
        #if DEBUG
            // Temporary hack for DEBUG: pass the private key via the protocol configuration
            // This will be removed when ProTUN V2 lands with key management
            protocolConfiguration.setProviderConfiguration(value: privateKey, forKey: "privateKey")
        #endif
    }

    static var wireGuardConfigurator: ManagerConfigurator {
        ManagerConfigurator(
            configure: { manager, operation in
                manager.onDemandRules = [NEOnDemandRuleConnect()]

                switch operation {
                case let .connection(connectionIntent):
                    switch connectionIntent.protocolConfiguration {
                    case .ike:
                        manager.protocolConfiguration = try ikeConfiguration(with: connectionIntent)
                    case .wireGuard:
                        // also persists the configuration to the keychain.
                        let protocolConfig = try await providerConfiguration(with: connectionIntent)
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

    private static func ikeConfiguration(with intent: ServerConnectionIntent) throws -> NEVPNProtocolIKEv2 {
        let config = NEVPNProtocolIKEv2()

        @Dependency(\.vpnKeychain) var keychain
        let username: String
        let passwordReference: Data
        do {
            let credentials = try keychain.fetch()
            username = credentials.name
            passwordReference = try keychain.fetchOpenVpnPassword()
        } catch {
            throw IkeConfiguratorError.ikeCredentialsUnavailable(error)
        }

        config.username = ikeUsername(baseUsername: username, features: intent.features, endpointID: intent.server.endpoint.id)
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

    private static func ikeUsername(baseUsername: String, features: VPNConnectionFeatures, endpointID: String) -> String {
        let components = ikeUsernameComponents(features: features, endpointID: endpointID)
        let suffix = components.reduce("") {
            $0 + "\(IkeUsernameComponent.concatChar)" + $1.usernameSuffix
        }
        return baseUsername + suffix
    }

    private static func ikeUsernameComponents(features: VPNConnectionFeatures, endpointID: String) -> [IkeUsernameComponent] {
        #if os(iOS)
            var components: [IkeUsernameComponent] = [.iosClient]
        #else
            var components: [IkeUsernameComponent] = [.macClient]
        #endif

        switch features.netshield {
        case .off:
            break
        case .level1:
            components += [.netShieldLevel1]
        case .level2:
            components += [.netShieldLevel2]
        case .level3:
            components += [.netShieldLevel3]
        }

        // Legacy encoding uses inverted logic for accelerator:
        // send `nst` when accelerator is disabled.
        if !features.vpnAccelerator {
            components += [.vpnAcceleratorDisabled]
        }

        if let label = features.bouncing, !label.isEmpty {
            components += [.label(label)]
        }

        if features.natType == .moderateNAT {
            components += [.moderateNAT]
        }

        if let safeMode = features.safeMode {
            components += [.safeMode(safeMode)]
        }

        if features.portForwarding == true {
            components += [.portForwardingEnabled]
        }

        // Endpoint token must be explicit to avoid collisions with feature flags.
        components += [.endpointID(endpointID)]
        return components
    }
}

enum WireguardConfiguratorError: Error {
    case entryUnavailableForTransport(Domain.WireGuardTransport)
    case incorrectProtocolConfiguration
    case configurationEncodingError(Error)
    case keychainImplementationError(TunnelKeychainImplementationError)
    case keychainError(Error)
    /// macOS-only: pushing the WireGuard config to the extension via XPC failed (no remote
    /// object, broken connection, etc.). The resulting `NETunnelProviderProtocol` would have
    /// no password reference and the tunnel would fail to start without an actionable error.
    case configurationXPCWriteFailed
}

/// Errors raised while building an IKEv2 `NEVPNProtocolIKEv2` configuration. Kept separate
/// from `WireguardConfiguratorError` so callers can pattern-match on protocol-specific
/// failures without conflating the two transports.
enum IkeConfiguratorError: Error {
    /// VPN keychain credentials could not be read while preparing the IKE configuration.
    case ikeCredentialsUnavailable(Error)
}

enum IkeUsernameComponent {
    static let concatChar: Character = "+"

    case iosClient
    case macClient
    case netShieldLevel1
    case netShieldLevel2
    case netShieldLevel3
    case vpnAcceleratorDisabled
    case label(String)
    case moderateNAT
    case safeMode(Bool)
    case portForwardingEnabled
    case endpointID(String)

    var usernameSuffix: String {
        switch self {
        case .iosClient:
            "pi"
        case .macClient:
            "pm"
        case .netShieldLevel1:
            "f1"
        case .netShieldLevel2:
            "f2"
        case .netShieldLevel3:
            "f3"
        case .vpnAcceleratorDisabled:
            "nst"
        case let .label(label):
            "b:\(label)"
        case .moderateNAT:
            "nr"
        case let .safeMode(enabled):
            enabled ? "sm" : "nsm"
        case .portForwardingEnabled:
            "pmp"
        case let .endpointID(endpointID):
            "ep:\(endpointID)"
        }
    }
}

private extension NETunnelProviderProtocol {
    var isProTUN: Bool {
        providerBundleIdentifier?.contains("ProTUN") ?? false
    }
}
