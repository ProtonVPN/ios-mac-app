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
import os.log
import vpncore

protocol SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager
}

class SystemExtensionManager: NSObject {
    
    typealias Factory = PropertiesManagerFactory & CoreAlertServiceFactory
    
    fileprivate let factory: Factory
    fileprivate let extensionIdentifier = "ch.protonvpn.mac.OpenVPN-Extension"
    fileprivate let log = OSLog(subsystem: "ProtonVPN", category: "ProtonTechnologies-SystemExtensionManager")
    fileprivate var silent: Bool = false
    fileprivate lazy var propertiesManager: PropertiesManagerProtocol = self.factory.makePropertiesManager()
    fileprivate lazy var alertService: CoreAlertService = self.factory.makeCoreAlertService()
    
    private var shouldNotifyInstall = false
    private var transportProtocol: VpnProtocol.TransportProtocol = .tcp
    private var completionCallback: VpnProtocolCallback?
    
    init( factory: Factory ) {
        self.factory = factory
        super.init()
    }
    
    func checkSystemExtensionState(silent: Bool = false) {
        self.silent = silent
        guard #available(OSX 10.15, *) else {
            self.propertiesManager.vpnProtocol = .ike
            return
        }
        os_log(.debug, log: self.log, "checkSystemExtensionState ")
        switch propertiesManager.vpnProtocol {
        case .openVpn(let transport):
            requestExtensionInstall(transport, completion: { vpnProtocol in
                self.propertiesManager.vpnProtocol = vpnProtocol
            })
        default:
            return
        }
    }
    
    func requestExtensionInstall( _ transportProtocol: VpnProtocol.TransportProtocol, completion: @escaping VpnProtocolCallback ) {
        shouldNotifyInstall = false
        guard #available(OSX 10.15, *) else {
            self.propertiesManager.vpnProtocol = .ike
            return
        }
        os_log(.debug, log: self.log, "requestExtensionInstall ")
        self.completionCallback = completion
        self.transportProtocol = transportProtocol
        self.propertiesManager.vpnProtocol = .ike
        completion(.ike)
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
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
        os_log(.debug, log: self.log, "requestNeedsUserApproval")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        // User gave access
        switch result {
        case .completed:
            os_log(.debug, log: self.log, "request result: .completed")
            propertiesManager.vpnProtocol = .openVpn(transportProtocol)
            if !silent && shouldNotifyInstall {
                alertService.push(alert: OpenVPNEnabledAlert())
            }
            
        case .willCompleteAfterReboot:
            os_log(.debug, log: self.log, "request result: .willCompleteAfterReboot")
            // Display reconnect popup
            propertiesManager.vpnProtocol = .openVpn(transportProtocol)
        }
        self.completionCallback?(propertiesManager.vpnProtocol)
        self.completionCallback = nil
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        
        os_log(.debug, log: self.log, "request error: %{public}@", "\(error)")
        if completionCallback == nil { return }
        
        if let typedError = error as? OSSystemExtensionError, typedError.code == OSSystemExtensionError.requestCanceled {
            // Actually a success, there was no need in reinstalling extension
            propertiesManager.vpnProtocol = .openVpn(transportProtocol)
            self.completionCallback?(propertiesManager.vpnProtocol)
            self.completionCallback = nil
            return
        }
        
        // Display error group
        propertiesManager.vpnProtocol = .ike
        self.completionCallback?(propertiesManager.vpnProtocol)
        self.completionCallback = nil
        if silent { return }
        alertService.push(alert: OpenVPNInstallingErrorAlert())
    }
}
