//
//  SystemExtensionManager.swift
//  ProtonVPN - Created on 07/12/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import SystemExtensions
import vpncore

protocol SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager
}

protocol SystemExtensionManager {
    
    typealias FinishedCallback = ((Result<Void, Error>) -> Void)
    typealias StatusCallback = ((SystemExtensionStatus) -> Void)
    
    func extenstionStatus(forType type: SystemExtensionType, completion: @escaping StatusCallback)
    func requestExtensionInstall(forType type: SystemExtensionType, completion: @escaping FinishedCallback)
    func requestExtensionUninstall(forType type: SystemExtensionType, completion: @escaping FinishedCallback)
}

struct SystemExtensionManagerNotification {
    static let installationSuccess = Notification.Name("OpenVPNExtensionInstallSuccess")
    static let installationError = Notification.Name("OpenVPNExtensionInstallError")
}

enum SystemExtensionType: String, CaseIterable {
    case openVPN = "ch.protonvpn.mac.OpenVPN-Extension"
    case wireGuard = "ch.protonvpn.mac.WireGuard-Extension"
    
    var machServiceName: String {
        let teamId = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String
        return "\(teamId)group.\(rawValue)"
    }
}

enum SystemExtensionStatus {
    case notInstalled
    case outdated
    case ok
}

class SystemExtensionManagerImplementation: NSObject, SystemExtensionManager {
    
    typealias Factory = PropertiesManagerFactory & XPCConnectionsRepositoryFactory
    
    fileprivate let factory: Factory
    fileprivate lazy var propertiesManager: PropertiesManagerProtocol = self.factory.makePropertiesManager()
    fileprivate lazy var xpcConnectionsRepository: XPCConnectionsRepository = self.factory.makeXPCConnectionsRepository()
        
    private var shouldNotifyInstall = false
    private var completionCallbacks = [String: SystemExtensionManager.FinishedCallback]()
    
    private var sysExUninstallRequestResultHandler = SystemExtensionUninstallRequestDelegate()
    
    private var xpcConnections = [String: XPCServiceUser]()
    
    init(factory: Factory) {
        self.factory = factory
        super.init()
    }
    
    func extenstionStatus(forType type: SystemExtensionType, completion: @escaping StatusCallback) {
        xpcConnectionsRepository.getXpcConnection(for: type.machServiceName).getVersion(completionHandler: { result in
            guard let data = result, let info = try? JSONDecoder().decode(ExtensionInfo.self, from: data) else {
                log.info("SysEx (\(type)) didn't return its version. Probably not yet installed.", category: .sysex)
                return completion(.notInstalled)
            }
            log.info("Got sysex (\(type)) version from extension: \(info)", category: .sysex)
            
            let appVersion = ExtensionInfo.current
            switch info.compare(to: appVersion) {
            case .orderedAscending:
                completion(.outdated)
                
            case .orderedDescending:
                log.info("SysEx version (\(info)) is higher than apps version (\(appVersion)", category: .sysex)
                completion(.outdated)
                
            case .orderedSame:
                completion(.ok)
            }
        })
    }
    
    func requestExtensionInstall(forType type: SystemExtensionType, completion: @escaping SystemExtensionManager.FinishedCallback) {
        shouldNotifyInstall = false

        log.info("requestExtensionInstall for \(type)")
        completionCallbacks.updateValue(completion, forKey: type.rawValue)
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: type.rawValue,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    /// Ask OS to uninstall our Network Extension
    func requestExtensionUninstall(forType type: SystemExtensionType, completion: @escaping SystemExtensionManager.FinishedCallback) {
        log.info("requestExtensionUninstall for \(type)")
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: type.rawValue,
            queue: .main
        )
        sysExUninstallRequestResultHandler.completion = completion
        request.delegate = sysExUninstallRequestResultHandler
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension SystemExtensionManagerImplementation: OSSystemExtensionRequestDelegate {
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        
        return .replace // Have to always replace extension to make system ask for permission to install sysex even after failed first attempt.
        
        // Return cancel on equal version, when/if Apple responds to bug report FB8978342.
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        log.info("SysEx install requestNeedsUserApproval (\(request.identifier))")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        log.info("SysEx (\(request.identifier)) install request result: \(result.rawValue)")
        
        completionCallbacks[request.identifier]?(.success)
        completionCallbacks[request.identifier] = nil
        
        NotificationCenter.default.post(name: SystemExtensionManagerNotification.installationSuccess, object: nil)
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        log.error("SysEx (\(request.identifier)) install request failed with error: \(error)")
        guard completionCallbacks[request.identifier] != nil else { return }
        
        if let typedError = error as? OSSystemExtensionError, typedError.code == OSSystemExtensionError.requestSuperseded {
            return // User requested one more time
        }
        
        // Display error group
        completionCallbacks[request.identifier]?(.failure(error))
        completionCallbacks[request.identifier] = nil
        NotificationCenter.default.post(name: SystemExtensionManagerNotification.installationError, object: error)
    }
}

class SystemExtensionUninstallRequestDelegate: NSObject, OSSystemExtensionRequestDelegate {
    
    var completion: SystemExtensionManager.FinishedCallback?
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        log.info("SysEx (\(request.identifier)) request finished with result: \(result.rawValue)", category: .sysex)
        completion?(.success)
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        log.error("SysEx (\(request.identifier)) failed with error: \(error)", category: .sysex)
        completion?(.failure(error))
    }
    
}
