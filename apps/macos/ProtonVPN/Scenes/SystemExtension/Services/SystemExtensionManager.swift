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
    
    func requestExtensionInstall(completion: @escaping FinishedCallback)
    func requestExtensionUninstall(completion: @escaping FinishedCallback)
}

struct SystemExtensionManagerNotification {
    static let installationSuccess = Notification.Name("OpenVPNExtensionInstallSuccess")
    static let installationError = Notification.Name("OpenVPNExtensionInstallError")
}

class SystemExtensionManagerImplementation: NSObject, SystemExtensionManager {
    
    typealias Factory = CoreAlertServiceFactory & PropertiesManagerFactory
    
    fileprivate let factory: Factory
    fileprivate lazy var alertService: CoreAlertService = self.factory.makeCoreAlertService()
    fileprivate lazy var propertiesManager: PropertiesManagerProtocol = self.factory.makePropertiesManager()
    
    fileprivate let extensionIdentifier = "ch.protonvpn.mac.OpenVPN-Extension"
    
    private var shouldNotifyInstall = false
    private var completionCallback: SystemExtensionManager.FinishedCallback?
    
    private var sysExUninstallRequestResultHandler = SystemExtensionUninstallRequestDelegate()
    
    init(factory: Factory) {
        self.factory = factory
        super.init()
    }
    
    func requestExtensionInstall(completion: @escaping SystemExtensionManager.FinishedCallback) {
        shouldNotifyInstall = false

        PMLog.D("requestExtensionInstall")
        self.completionCallback = completion
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    /// Ask OS to uninstall our Network Extension
    func requestExtensionUninstall(completion: @escaping SystemExtensionManager.FinishedCallback) {
        PMLog.D("requestExtensionUninstall")
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
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
        // Requires user action
        shouldNotifyInstall = true
        
        self.alertService.push(alert: SystemExtensionTourAlert())
        
        PMLog.D("SysEx install requestNeedsUserApproval")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        PMLog.D("SysEx install request result: \(result.rawValue)")

        self.completionCallback?(.success(()))
        self.completionCallback = nil
        
        NotificationCenter.default.post(name: SystemExtensionManagerNotification.installationSuccess, object: nil)
        if shouldNotifyInstall {
            alertService.push(alert: SysexEnabledAlert())
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        PMLog.D("SysEx install request failed with error: \(error)")
        guard completionCallback != nil else { return }
        
        if let typedError = error as? OSSystemExtensionError, typedError.code == OSSystemExtensionError.requestSuperseded {
            return // User requested one more time
        }
        
        // Display error group
        self.completionCallback?(.failure(error))
        self.completionCallback = nil
        NotificationCenter.default.post(name: SystemExtensionManagerNotification.installationError, object: error)
        alertService.push(alert: SysexInstallingErrorAlert())
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
        PMLog.D("SysEx request finished with result: \(result.rawValue)")
        completion?(.success(()))
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        PMLog.D("SysEx failed with error: \(error)")
        completion?(.failure(error))
    }
    
}
