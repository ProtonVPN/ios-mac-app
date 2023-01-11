//
//  IOSVpnCredentialsConfiguratorFactory.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import VPNShared

final class IOSVpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory {
    
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnKeychain: VpnKeychainProtocol
    
    init(propertiesManager: PropertiesManagerProtocol, vpnKeychain: VpnKeychainProtocol) {
        self.propertiesManager = propertiesManager
        self.vpnKeychain = vpnKeychain
    }
    
    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        switch vpnProtocol {
        case .ike:
            return KeychainRefVpnCredentialsConfigurator()
        case .openVpn:
            return OVPNiOSCredentialsConfigurator()
        case .wireGuard:
            return WGiOSVpnCredentialsConfigurator(propertiesManager: propertiesManager,
                                                   vpnKeychain: vpnKeychain)
        }
    }
    
}
