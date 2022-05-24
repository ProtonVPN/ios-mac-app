//
//  File.swift
//  Core
//
//  Created by Jaroslav on 2021-05-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

open class WireguardProtocolFactory {

    private let bundleId: String
    private let appGroup: String
    private let propertiesManager: PropertiesManagerProtocol
    private var vpnManager: NETunnelProviderManager?
    
    public init(bundleId: String, appGroup: String, propertiesManager: PropertiesManagerProtocol) {
        self.bundleId = bundleId
        self.appGroup = appGroup
        self.propertiesManager = propertiesManager
    }
        
    open func logs(completion: @escaping (String?) -> Void) {
        guard let fileUrl = logFile() else {
            completion(nil)
            return
        }
        do {
            let log = try String(contentsOf: fileUrl)
            completion(log)
        } catch {
            log.error("Error reading WireGuard log file", category: .app, metadata: ["error": "\(error)"])
            completion(nil)
        }
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
    
    private func logFile() -> URL? {
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            log.error("Cannot obtain shared folder URL for appGroup", category: .app, metadata: ["appGroupId": "\(appGroup)", "protocol": "WireGuard"])
            return nil
        }
        return sharedFolderURL.appendingPathComponent(CoreAppConstants.LogFiles.wireGuard)
    }

    /// Tries to flish logs to a logfile. Call handler with true if flush succeeded of false otherwise.
    public func flushLogs(responseHandler: @escaping (_ success: Bool) -> Void) {
        vpnProviderManager(for: .status) { manager, error in
            guard let manager = manager, let connection = (manager as? NETunnelProviderManager)?.connection as? NETunnelProviderSession else {
                responseHandler(false)
                return
            }
            do {
                try connection.sendProviderMessage(Message.flushLogsToFile.data) { _ in
                    responseHandler(true)
                }
            } catch {
                responseHandler(false)
            }
        }
    }

}

extension VpnManagerConfiguration {

    private var persistentKeepalive: Int? {
        return 25
    }
    
    public func asWireguardConfiguration(config: WireguardConfig) -> String {
        var output = "[Interface]\n"
        
        if let authData = authData {
            output.append("PrivateKey = \(authData.clientKey.base64X25519Representation)\n")
        }
        output.append("Address = \(config.address)\n")
        output.append("DNS = \(config.dns)\n")
        
        output.append("\n[Peer]\n")
        if let serverPublicKey = serverPublicKey {
            output.append("PublicKey = \(serverPublicKey)\n")
        }
        output.append("AllowedIPs = \(config.allowedIPs)\n")
        output.append("Endpoint = \(entryServerAddress):\(ports.first!)\n")
        if let persistentKeepalive = persistentKeepalive {
            output.append("PersistentKeepalive = \(persistentKeepalive)")
        }
        
        return output
    }
}
