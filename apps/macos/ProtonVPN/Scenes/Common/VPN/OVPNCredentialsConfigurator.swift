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
        xpcServiceUser.setCredentials(username: configuration.username, password: configuration.password, completionHandler: { success in
            PMLog.D("Credentials set result: \(success ? "success" : "failure")")
            completionHandler(protocolConfig)
        })
    }
    
}
