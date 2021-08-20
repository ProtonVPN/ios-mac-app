//
//  OVPNiOSCredentialsConfigurator.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import vpncore
import TunnelKit

final class OVPNiOSCredentialsConfigurator: VpnCredentialsConfigurator {
    
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        
        let storage = TunnelKit.Keychain(group: AppConstants.AppGroups.main)
        try? storage.set(password: configuration.password, for: configuration.username, context: AppConstants.NetworkExtensions.openVpn)
        
        completionHandler(protocolConfig)
    }
    
}
