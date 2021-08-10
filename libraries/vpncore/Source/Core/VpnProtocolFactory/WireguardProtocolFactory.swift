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
    private var vpnManager: NETunnelProviderManager?
    
    public init(bundleId: String, appGroup: String, propertiesManager: PropertiesManagerProtocol) {
        self.bundleId = bundleId
        self.appGroup = appGroup
        self.propertiesManager = propertiesManager
    }

}

extension WireguardProtocolFactory: VpnProtocolFactory {
    
    private enum Message: UInt8 {
        // Standard messages
        case getRuntimeTunnelConfiguration = 0
        // Proton messages
        case flushLogsToFile = 101
        
        var data: Data {
            return Data([self.rawValue])
        }        
    }
            
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleId
        protocolConfiguration.serverAddress = configuration.entryServerAddress
                
        let keychain = VpnKeychain()
        protocolConfiguration.passwordReference = try? keychain.store(wireguardConfiguration: configuration.wireguardConfig)
        protocolConfiguration.disconnectOnSleep = true
        
        #if os(macOS)
        protocolConfiguration.providerConfiguration = ["UID": getuid()]
        #endif
        
        return protocolConfiguration
    }
    
    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement, completion: @escaping (NEVPNManager?, Error?) -> Void) {
        if requirement == .status, let vpnManager = vpnManager {
            completion(vpnManager, nil)
        } else {
            loadManager(completion: completion)
        }
    }
    
    private func loadManager(completion: @escaping (NEVPNManager?, Error?) -> Void) {
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
            
            self.vpnManager = managers.first(where: { [unowned self] (manager) -> Bool in
                return (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.bundleId
            }) ?? NETunnelProviderManager()

            completion(self.vpnManager, nil)
        }
    }
    
    public func connectionStarted(configuration: VpnManagerConfiguration, completion: @escaping () -> Void) {
        self.flushLogs(self.vpnManager) // Creates logfile so it's ready if/when user needs it.
        completion()
    }
    
    public func logs(completion: @escaping (String?) -> Void) {
        guard let fileUrl = logFile() else {
            completion(nil)
            return
        }
        do {
            let log = try String(contentsOf: fileUrl)
            completion(log)
        } catch {
            PMLog.D("Error reading WireGuard log file: \(error)")
            completion(nil)
        }
    }
    
    public func logFile() -> URL? {
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            PMLog.D("Cannot obtain shared folder URL for appGroupId \(appGroup) ")
            return nil
        }
        // Flush logs to file. Async, but should be done before user get's the file.
        vpnProviderManager(for: .configuration) { manager, error in 
            guard let manager = manager else { return }
            self.flushLogs(manager)
        }
        
        return sharedFolderURL.appendingPathComponent("WireGuard.log")
    }
    
    private func flushLogs(_ manager: NEVPNManager?) {
        try? ((manager as? NETunnelProviderManager)?.connection as? NETunnelProviderSession)?.sendProviderMessage(Message.flushLogsToFile.data, responseHandler: nil)
    }
        
}

extension VpnManagerConfiguration {
    
    var wireguardConfig: String {
        var output = "[Interface]\n"
        
        if let authData = authData {
            output.append("PrivateKey = \(authData.clientKey.base64X25519Representation)\n")
        }
        output.append("Address = 10.2.0.2/32\n")
        output.append("DNS = 10.2.0.1\n")
        
        output.append("\n[Peer]\n")
        if let serverPublicKey = serverPublicKey {
            output.append("PublicKey = \(serverPublicKey)\n")
        }
        output.append("AllowedIPs = 0.0.0.0/0\n")
        output.append("Endpoint = \(entryServerAddress):51820\n")
        
        return output
    }
    
}
