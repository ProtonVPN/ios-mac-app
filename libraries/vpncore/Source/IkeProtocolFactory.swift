//
//  IkeProtocolFactory.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

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
        
        // Identify client to vpn server
        #if os(OSX)
        config.remoteIdentifier = "ikev2-macos"
        #else
        config.remoteIdentifier = "ikev2-ios"
        #endif
        
        config.username = configuration.username
        config.localIdentifier = configuration.username // makes it easier to troubleshoot connection issues server-side
        config.serverAddress = configuration.entryServerAddress
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
