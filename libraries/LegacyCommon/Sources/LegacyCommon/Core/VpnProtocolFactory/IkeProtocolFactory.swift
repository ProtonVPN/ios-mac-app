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

import Foundation
import NetworkExtension

public protocol IkeProtocolFactoryCreator {
    func makeIkeProtocolFactory() -> IkeProtocolFactory
}

public class IkeProtocolFactory: VpnProtocolFactory {
    public typealias Factory = NEVPNManagerWrapperFactory

    private let vpnManager: NEVPNManagerWrapper
    
    public init(factory: Factory) {
        self.vpnManager = factory.makeNEVPNManagerWrapper()
    }
    
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        let config = NEVPNProtocolIKEv2()

        config.localIdentifier = configuration.username // makes it easier to troubleshoot connection issues server-side
        config.remoteIdentifier = configuration.hostname
        config.serverAddress = configuration.entryServerAddress
        config.useExtendedAuthentication = true
        config.disconnectOnSleep = false
        config.enablePFS = false
        config.deadPeerDetectionRate = .high
        
        #if os(OSX)
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
    
    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement) async throws -> NEVPNManagerWrapper {
        try await withCheckedThrowingContinuation { continuation in
            vpnManager.loadFromPreferences { loadError in
                if let loadError {
                    continuation.resume(throwing: loadError)
                } else {
                    continuation.resume(returning: self.vpnManager)
                }
            }
        }
    }
    
    public func logs(completion: @escaping (String?) -> Void) {
        completion(nil)
    }
    
}
