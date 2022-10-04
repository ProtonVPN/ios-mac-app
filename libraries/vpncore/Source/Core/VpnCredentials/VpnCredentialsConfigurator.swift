//
//  VpnCredentialsConfigurator.swift
//  Core
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

/// Used to prepare credentials used by VPN protocol implementation to connect to the server.
public protocol VpnCredentialsConfigurator {
    /// Is called right before saving VPN configuration and starting a connection.
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void)
}

/// Used for IKEv2 on macos and ios and sets username and password keychain reference for use by network extension.
public class KeychainRefVpnCredentialsConfigurator: VpnCredentialsConfigurator {
    
    public init() {        
    }
    
    public func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        protocolConfig.username = configuration.username
        protocolConfig.passwordReference = configuration.passwordReference
        
        completionHandler(protocolConfig)
    }
    
}
