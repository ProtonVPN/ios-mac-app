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
    private let vpnKeychain: VpnKeychainProtocol
    
    init(propertiesManager: PropertiesManagerProtocol, vpnKeychain: VpnKeychainProtocol) {
        self.propertiesManager = propertiesManager
        self.vpnKeychain = vpnKeychain
    }
    
    func prepareCredentials(for protocolConfig: NEVPNProtocol, configuration: VpnManagerConfiguration, completionHandler: @escaping (NEVPNProtocol) -> Void) {
        protocolConfig.username = configuration.username // Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)

        let encoder = JSONEncoder()
        let version: StoredWireguardConfig.Version = .v1
        let storedConfig = StoredWireguardConfig(vpnManagerConfig: configuration,
                                                 wireguardConfig: propertiesManager.wireguardConfig)

        do {
            var configData = Data([UInt8(version.rawValue)])
            configData.append(try encoder.encode(storedConfig))

            protocolConfig.passwordReference = try vpnKeychain
                .store(wireguardConfiguration: configData)
        } catch {
            // XXX: It doesn't seem like it's possible to log from here?
            // log.error("Could not store wireguard config: \(error)")
        }

        completionHandler(protocolConfig)
    }
    
}
