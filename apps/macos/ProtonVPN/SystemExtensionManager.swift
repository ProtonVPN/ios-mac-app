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

final class SystemExtensionManager: NSObject {
    
    typealias Factory = PropertiesManagerFactory & CoreAlertServiceFactory
    
    fileprivate let factory: Factory
    fileprivate lazy var propertiesManager: PropertiesManagerProtocol = self.factory.makePropertiesManager()
    fileprivate lazy var alertService: CoreAlertService = self.factory.makeCoreAlertService()
    
    fileprivate let extensionIdentifier = "ch.protonvpn.mac.OpenVPN-Extension"
    fileprivate var silent: Bool = false
    
    private var shouldNotifyInstall = false
    private var completionCallback: ((Bool) -> Void)?
    
    private var sysExUninstallRequestResultHandler = SystemExtensionUninstallRequestDelegate()
    
    init(factory: Factory) {
        self.factory = factory
        super.init()
    }
    
    func checkSystemExtensionState(silent: Bool, requestInstall: Bool, completion: @escaping (Bool) -> Void) {
        self.silent = silent

        PMLog.D("checkSystemExtensionState")
        guard requestInstall else {
            completion(false)
            return
        }

        requestExtensionInstall(completion: completion)
    }
    
    func requestExtensionInstall(completion: @escaping (Bool) -> Void) {
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
    func requestExtensionUninstall(completion: @escaping ((Error?) -> Void)) {
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

@available(OSX 10.15, *)
extension SystemExtensionManager: OSSystemExtensionRequestDelegate {
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        
        return .replace // Have to always replace extension to make system ask for permission to install sysex even after failed first attempt.
        
        // Change to the following code, when/if Apple responds to bug report FB8978342.
        
//        propertiesManager.vpnProtocol = .openVpn(transportProtocol)
//        propertiesManager.openVPNExtensionTourDisplayed = true
//
//        if existing.bundleShortVersion.compareVersion(to: ext.bundleShortVersion) == ComparisonResult.orderedAscending {
//            return .replace
//        }
//
//        self.completionCallback?(propertiesManager.vpnProtocol)
//        self.completionCallback = nil
//        return .cancel
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // Requires user action
        shouldNotifyInstall = true
        propertiesManager.openVPNExtensionTourDisplayed = true
        PMLog.D("SysEx install requestNeedsUserApproval")
        completionCallback?(false)
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        PMLog.D("SysEx install request result: \(result.rawValue)")
        // User gave access
        switch result {
        case .completed:
            completionCallback?(true)
            if !silent && shouldNotifyInstall {
                alertService.push(alert: OpenVPNEnabledAlert())
            }
            
        case .willCompleteAfterReboot:
            // Display reconnect popup
            completionCallback?(true)
        }
        self.completionCallback = nil
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        PMLog.D("SysEx install request failed with error: \(error)")
        
        if let typedError = error as? OSSystemExtensionError, typedError.code == OSSystemExtensionError.requestCanceled {
            // Actually a success, there was no need in reinstalling extension
            self.completionCallback?(true)
            self.completionCallback = nil
            return
        }
        
        // Display error group
        self.completionCallback?(false)
        self.completionCallback = nil

        guard !silent else {
            return
        }

        alertService.push(alert: OpenVPNInstallingErrorAlert())
    }
}

@available(OSX 10.15, *)
final class SystemExtensionUninstallRequestDelegate: NSObject, OSSystemExtensionRequestDelegate {
    
    var completion: ((Error?) -> Void)?
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        PMLog.D("SysEx request finished with result: \(result.rawValue)")
        completion?(nil)
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        PMLog.D("SysEx failed with error: \(error)")
        completion?(error)
    }
    
}
