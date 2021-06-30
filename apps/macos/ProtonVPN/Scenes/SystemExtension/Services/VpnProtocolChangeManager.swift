//
//  VpnProtocolChangeManager.swift
//  ProtonVPN - Created on 2021-04-09.
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
import vpncore

protocol VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager
}

extension DependencyContainer: VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager {
        return VpnProtocolChangeManagerImplementation(factory: self)
    }
}

/// Class to request VPN protocol change.
/// Takes care of checking if user is currently connected, if sysex is installed, etc.
protocol VpnProtocolChangeManager {
    func change(toProcol: VpnProtocol)
}

final class VpnProtocolChangeManagerImplementation: VpnProtocolChangeManager {
    
    typealias Factory = PropertiesManagerFactory
        & CoreAlertServiceFactory
        & SystemExtensionManagerFactory
        & VpnGatewayFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func change(toProcol vpnProtocol: VpnProtocol) {
        guard vpnGateway.connection == .connected || vpnGateway.connection == .connecting else {
            set(vpnProtocol: vpnProtocol)
            return
        }
        
        alertService.push(alert: ReconnectOnSettingsChangeAlert {
            // Protocol change to OpenVPN is asynchronuos, so we will wait for a notification
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(forName: PropertiesManager.vpnProtocolNotification, object: nil, queue: nil) { [weak self] (notification) in
                if let newProtocol = notification.object as? VpnProtocol {
                    PMLog.D("New protocol set to \(newProtocol). VPN will reconnect.")
                    self?.vpnGateway.reconnect(with: newProtocol)
                }
                NotificationCenter.default.removeObserver(token!)
            }
            self.set(vpnProtocol: vpnProtocol)
        })
    }
    
    private func set(vpnProtocol: VpnProtocol) {
        
        switch vpnProtocol {
        case .ike:
            propertiesManager.vpnProtocol = vpnProtocol
            
        case .openVpn:
            let requestExtensionCallback: (() -> Void) = {
                self.systemExtensionManager.requestExtensionInstall { result in
                    if case .success = result {
                        self.propertiesManager.vpnProtocol = vpnProtocol
                    }
                }
            }
            
            if propertiesManager.openVPNExtensionTourDisplayed {
                requestExtensionCallback()
                
            } else {
                alertService.push(alert: SysexInstallationRequiredAlert(continueHandler: { [unowned self] in
                    propertiesManager.openVPNExtensionTourDisplayed = true
                    requestExtensionCallback()
                    self.alertService.push(alert: SystemExtensionTourAlert())
                }, cancel: nil, dismiss: nil))
            }
        
        case .wireGuard:
            #warning("Implement proper logic")
            propertiesManager.vpnProtocol = vpnProtocol
        }
        
    }
        
}
