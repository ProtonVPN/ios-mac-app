//
//  IOSVpnCredentialsConfiguratorFactory.swift
//  ProtonVPN
//
//  Created by Jaroslav Oo on 2021-08-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

import Domain
import VPNShared
import LegacyCommon

final class IOSVpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory {
    
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnKeychain: VpnKeychainProtocol
    private let vpnAuthentication: VpnAuthentication
    
    init(propertiesManager: PropertiesManagerProtocol, vpnKeychain: VpnKeychainProtocol, vpnAuthentication: VpnAuthentication) {
        self.propertiesManager = propertiesManager
        self.vpnKeychain = vpnKeychain
        self.vpnAuthentication = vpnAuthentication
    }
    
    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        switch vpnProtocol {
        case .ike:
            return KeychainRefVpnCredentialsConfigurator()
        case .openVpn:
            fatalError("OpenVPN has been deprecated")
        case .wireGuard:
            return WGiOSVpnCredentialsConfigurator(propertiesManager: propertiesManager,
                                                   vpnKeychain: vpnKeychain)
        }
    }
    
}
