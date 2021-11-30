//
//  MacVpnCredentialsConfiguratorFactory.swift
//  ProtonVPN WireGuard
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore

final class MacVpnCredentialsConfiguratorFactory: VpnCredentialsConfiguratorFactory {
    
    private let propertiesManager: PropertiesManagerProtocol
    
    init(propertiesManager: PropertiesManagerProtocol) {
        self.propertiesManager = propertiesManager
    }
    
    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        switch vpnProtocol {
        case .ike:
            return KeychainRefVpnCredentialsConfigurator()
        case .openVpn:
            return OVPNCredentialsConfigurator(xpcServiceUser: XPCServiceUser(withExtension: SystemExtensionType.openVPN.machServiceName, logger: { log.debug("\($0)", category: .protocol) }))
        case .wireGuard:
            return WGVpnCredentialsConfigurator(xpcServiceUser: XPCServiceUser(withExtension: SystemExtensionType.wireGuard.machServiceName, logger: { log.debug("\($0)", category: .protocol) }),
                                                propertiesManager: propertiesManager)
        }
        
    }
    
}
