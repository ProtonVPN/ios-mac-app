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

import struct Domain.ServerConnectionIntent
import enum Domain.VPNFeatureFlagType
import enum Domain.VpnProtocol
import enum Domain.WireGuardTransport
import protocol Localization.LocalizedStringConvertible

import CoreConnection
import ProtonCoreFeatureFlags

public struct ConnectionConfiguration {
    /// Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)
    public let username: String
    public let wireguardConfig: WireguardConfig
}

public enum ConnectionConfigurationKey: DependencyKey {
    public static let testValue = ConnectionConfiguration(username: "mock_username", wireguardConfig: .init())
    public static var liveValue = ConnectionConfiguration(username: "ProtonVPN", wireguardConfig: .init())
}

extension DependencyValues {
    public var connectionConfiguration: ConnectionConfiguration {
        get { self[ConnectionConfigurationKey.self] }
        set { self[ConnectionConfigurationKey.self] = newValue }
    }
}

extension ManagerConfigurator {
    private static func configuration(with connectionIntent: ServerConnectionIntent) throws -> NETunnelProviderProtocol {
        @Dependency(\.bundleIDClient) var bundleIDClient
        let bundleID: String = bundleIDClient.bundleIdentifierForTarget()
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        let server = connectionIntent.server

        guard let entryIP = server.endpoint.entryIp(using: .wireGuard(connectionIntent.tunnelSettings.transport)) else {
            throw WireguardConfiguratorError.entryUnavailableForTransport(connectionIntent.tunnelSettings.transport)
        }

        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoint.id
        protocolConfiguration.serverAddress = entryIP
        protocolConfiguration.wgProtocol = connectionIntent.tunnelSettings.transport.rawValue

        @Dependency(\.connectionConfiguration) var connectionConfiguration
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        @Dependency(\.tunnelKeychain) var tunnelKeychain
        @Dependency(\.date) var date
        protocolConfiguration.username = nil // Only required for IKEv2.

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

        let encoder = JSONEncoder()
        let version: StoredWireguardConfig.Version = .v1
        let storedConfig = StoredWireguardConfig(
            wireguardConfig: connectionConfiguration.wireguardConfig,
            clientPrivateKey: authenticationStorage.getKeys().privateKey.base64X25519Representation,
            serverPublicKey: server.endpoint.x25519PublicKey,
            entryServerAddress: entryIP,
            ports: connectionIntent.tunnelSettings.ports,
            timestamp: date.now
        )

        var configData = Data([UInt8(version.rawValue)])
        do {
            try configData.append(encoder.encode(storedConfig))
        } catch {
            throw WireguardConfiguratorError.configurationEncodingError(error)
        }
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

    static var wireGuardConfigurator: ManagerConfigurator {
        ManagerConfigurator(
            configure: { manager, operation in
                manager.onDemandRules = [NEOnDemandRuleConnect()]

                switch operation {
                case let .connection(connectionIntent):
                    manager.vpnProtocolConfiguration = try configuration(with: connectionIntent)
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
            let transport = intent.tunnelSettings.transport
            let connectionProtocol = VpnProtocol.wireGuard(transport).localizedDescription
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
