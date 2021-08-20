//
//  SysExVpnCredentialsConfigurator.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-08-06.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import vpncore

final class WGVpnCredentialsConfigurator: VpnCredentialsConfigurator {
    
    private let xpcServiceUser: XPCServiceUser
    private let propertiesManager: PropertiesManagerProtocol
    
    init(xpcServiceUser: XPCServiceUser, propertiesManager: PropertiesManagerProtocol) {
        self.xpcServiceUser = xpcServiceUser
        self.propertiesManager = propertiesManager
    }
    
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        
        xpcServiceUser.setCredentials(username: "", password: configuration.asWireguardConfiguration(config: propertiesManager.wireguardConfig), completionHandler: { success in
            PMLog.D("Credentials set result: \(success ? "success" : "failure")")
            completionHandler(protocolConfig)
        })
    }
    
}
