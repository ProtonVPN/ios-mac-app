//
//  OVPNCredentialsConfigurator.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-08-09.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import vpncore

final class OVPNCredentialsConfigurator: VpnCredentialsConfigurator {
    
    private let xpcServiceUser: XPCServiceUser
    
    init(xpcServiceUser: XPCServiceUser) {
        self.xpcServiceUser = xpcServiceUser
    }
    
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        protocolConfig.username = configuration.username // Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)
        
        xpcServiceUser.setCredentials(username: configuration.username, password: configuration.password, completionHandler: { success in
            log.info("Credentials set result (ovpn): \(success ? "success" : "failure")", category: .sysex)
            completionHandler(protocolConfig)
        })
    }
    
}
