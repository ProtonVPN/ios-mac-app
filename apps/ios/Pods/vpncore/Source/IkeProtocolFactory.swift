//
//  IkeProtocolFactory.swift
//  ProtonVPN
//
//  Created by Hrvoje Bušić on 29/07/2017.
//  Copyright © 2017 ProtonVPN. All rights reserved.
//

import Foundation
import NetworkExtension

public struct VpnManagerConfiguration {
    
    public let serverId: String
    public let entryServerAddress: String
    public let exitServerAddress: String
    public let username: String
    public let password: Data
    
    public init(serverId: String, entryServerAddress: String, exitServerAddress: String, username: String, password: Data) {
        self.serverId = serverId
        self.entryServerAddress = entryServerAddress
        self.exitServerAddress = exitServerAddress
        self.username = username
        self.password = password
    }
}

public class IkeProtocolFactory {
    
    public static func create(_ configuration: VpnManagerConfiguration) -> NEVPNProtocol {
        let config = NEVPNProtocolIKEv2()
        
        config.username = configuration.username
        config.localIdentifier = configuration.username // makes it easier to troubleshoot connection issues server-side
        config.serverAddress = configuration.entryServerAddress
        config.remoteIdentifier = configuration.exitServerAddress
        config.useExtendedAuthentication = true
        config.passwordReference = configuration.password
        config.disconnectOnSleep = false
        config.enablePFS = false
        config.deadPeerDetectionRate = .high
        
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
