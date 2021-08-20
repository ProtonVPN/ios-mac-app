//
//  WGiOSVpnCredentialsConfigurator.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import vpncore

final class WGiOSVpnCredentialsConfigurator: VpnCredentialsConfigurator {
    
    private let propertiesManager: PropertiesManagerProtocol
    
    init(propertiesManager: PropertiesManagerProtocol) {
        self.propertiesManager = propertiesManager
    }
    
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        
        let keychain = VpnKeychain()
        protocolConfig.passwordReference = try? keychain.store(wireguardConfiguration: configuration.asWireguardConfiguration(config: propertiesManager.wireguardConfig))
        
        completionHandler(protocolConfig)
    }
    
}
