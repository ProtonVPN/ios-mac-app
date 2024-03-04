//
//  SysExVpnCredentialsConfigurator.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-08-06.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import LegacyCommon

final class WGVpnCredentialsConfigurator: VpnCredentialsConfigurator {
    
    private let xpcServiceUser: XPCServiceUser
    private let propertiesManager: PropertiesManagerProtocol
    
    init(xpcServiceUser: XPCServiceUser, propertiesManager: PropertiesManagerProtocol) {
        self.xpcServiceUser = xpcServiceUser
        self.propertiesManager = propertiesManager
    }
    
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        protocolConfig.username = configuration.username // Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)

        let storedConfig = StoredWireguardConfig(vpnManagerConfig: configuration,
                                                 wireguardConfig: propertiesManager.wireguardConfig)

        let version: StoredWireguardConfig.Version = .v1
        var configData = Data([UInt8(version.rawValue)])
        do {
            let encoder = JSONEncoder()
            configData.append(try encoder.encode(storedConfig))
        } catch {
            log.assertionFailure("Couldn't encode wireguard config: \(error)")
            completionHandler(protocolConfig)
        }

        xpcServiceUser.setConfigData(configData) { result in
            let success = result ? "success" : "failure"
            log.info("Credentials set result (wg): \(success)", category: .sysex)
            completionHandler(protocolConfig)
        }
    }
    
}
