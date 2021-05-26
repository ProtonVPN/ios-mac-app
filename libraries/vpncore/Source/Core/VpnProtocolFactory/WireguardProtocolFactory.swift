//
//  File.swift
//  Core
//
//  Created by Jaroslav on 2021-05-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

public class WireguardProtocolFactory {

    private let bundleId: String
    private let appGroup: String
    private let propertiesManager: PropertiesManagerProtocol
    
    public init(bundleId: String, appGroup: String, propertiesManager: PropertiesManagerProtocol) {
        self.bundleId = bundleId
        self.appGroup = appGroup
        self.propertiesManager = propertiesManager
    }

}

extension WireguardProtocolFactory: VpnProtocolFactory {
            
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleId
        protocolConfiguration.serverAddress = "172.83.45.3:51820"
                
        let config = """
                PUT CONFIG HERE
                """
        let key = "PVPN-WG-TEST"
        let keychain = VpnKeychain()
        try keychain.setPassword(config, forKey: key)
        protocolConfiguration.passwordReference = try? keychain.getPasswordRefference(forKey: key)
        
        #if os(macOS)
        protocolConfiguration.providerConfiguration = ["UID": getuid()]
        #endif
        
        return protocolConfiguration
    }
    
    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement, completion: @escaping (NEVPNManager?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let `self` = self else {
                completion(nil, ProtonVpnError.vpnManagerUnavailable)
                return
            }
            if let error = error {
                completion(nil, error)
                return
            }
            guard let managers = managers else {
                completion(nil, ProtonVpnError.vpnManagerUnavailable)
                return
            }
            
            let vpnManager = managers.first(where: { [unowned self] (manager) -> Bool in
                return (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.bundleId
            }) ?? NETunnelProviderManager()

            completion(vpnManager, nil)
        }
    }
    
    public func connectionStarted(configuration: VpnManagerConfiguration, completion: @escaping () -> Void) {
        completion()
    }
    
    public func logs(completion: @escaping (String?) -> Void) {
        completion(nil)
    }
    
    public func logFile(completion: @escaping (URL?) -> Void) {
        completion(nil)
    }
        
}
