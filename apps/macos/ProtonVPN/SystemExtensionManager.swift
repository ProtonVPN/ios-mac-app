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
        os_log(.debug, log: self.log, "Action for replacing %@ -> %@", "\(existing.bundleShortVersion) (\(existing.bundleVersion))", "\(ext.bundleShortVersion) (\(ext.bundleVersion))")
        
        propertiesManager.vpnProtocol = .openVpn(transportProtocol)
        
        if existing.bundleShortVersion.compareVersion(to: ext.bundleShortVersion) == ComparisonResult.orderedAscending {
            return .replace
        }
        
        self.completionCallback?(propertiesManager.vpnProtocol)
        self.completionCallback = nil
        return .cancel
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // Requires user action
        os_log(.debug, log: self.log, "requestNeedsUserApproval")
        if silent { return }
        let alert = OpenVPNInstallationRequiredAlert(continueHandler: { [unowned self] in
            self.alertService.push(alert: OpenVPNExtensionTourAlert())
        })
        alertService.push(alert: alert)
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        // User gave access
        os_log(.debug, log: self.log, "request result: %{public}@", "\(result)")
        switch result {
        case .completed:
            propertiesManager.vpnProtocol = .openVpn(transportProtocol)
            if !silent {
                alertService.push(alert: OpenVPNEnabledAlert())
            }
            
        case .willCompleteAfterReboot:
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
