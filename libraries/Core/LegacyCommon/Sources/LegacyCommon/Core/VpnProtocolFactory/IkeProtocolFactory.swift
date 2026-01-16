//
//  IkeProtocolFactory.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Foundation
import NetworkExtension

@DependencyClient
public struct IkeProtocolManager {
    public var create: @Sendable (_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol
    public var vpnProviderManager: @Sendable (_ for: VpnProviderManagerRequirement, _ completion: @escaping (NEVPNManagerWrapper?, Error?) -> Void) -> Void
    public var vpnProviderManagerAsync: @Sendable (_ for: VpnProviderManagerRequirement) async throws -> NEVPNManagerWrapper
    public var logs: @Sendable (_ completion: @escaping (String?) -> Void) -> Void
}

extension IkeProtocolManager: VpnProtocolFactory {
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        try create(configuration)
    }

    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement) async throws -> NEVPNManagerWrapper {
        try await vpnProviderManagerAsync(requirement)
    }
}

extension IkeProtocolManager: DependencyKey {
    public static let liveValue: IkeProtocolManager = {
        let vpnManager = Dependency(\.neVpnManagerClient).wrappedValue.makeManager()

        return IkeProtocolManager(
            create: { configuration in
                let config = NEVPNProtocolIKEv2()

                config.localIdentifier = configuration.username // makes it easier to troubleshoot connection issues server-side
                config.remoteIdentifier = configuration.hostname
                config.serverAddress = configuration.entryServerAddress
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
            },
            vpnProviderManager: { _, completion in
                vpnManager.loadFromPreferences { loadError in
                    if let loadError {
                        completion(nil, loadError)
                        return
                    }

                    completion(vpnManager, nil)
                }
            },
            vpnProviderManagerAsync: { _ in
                try await vpnManager.loadFromPreferences()
                return vpnManager
            },
            logs: { completion in
                completion(nil)
            }
        )
    }()
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var ikeProtocolManager: IkeProtocolManager {
        get { self[IkeProtocolManager.self] }
        set { self[IkeProtocolManager.self] = newValue }
    }
}

#if DEBUG
    extension IkeProtocolManager {
        static func testManager(managerMock: NEVPNManagerMock) -> IkeProtocolManager {
            IkeProtocolManager(
                create: { configuration in
                    let config = NEVPNProtocolIKEv2()
                    config.localIdentifier = configuration.username
                    config.remoteIdentifier = configuration.hostname
                    config.serverAddress = configuration.entryServerAddress
                    return config
                },
                vpnProviderManager: { _, completion in
                    completion(managerMock, nil)
                },
                vpnProviderManagerAsync: { _ in
                    managerMock
                },
                logs: { _ in }
            )
        }
    }
#endif
