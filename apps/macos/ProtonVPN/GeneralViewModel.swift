//
//  GeneralViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

class GeneralViewModel {
    
    typealias Factory = PropertiesManagerFactory & CoreAlertServiceFactory & AppStateManagerFactory & VpnGatewayFactory

    private let factory: Factory
    private lazy var propertiesManager: PropertiesManagerProtocol = self.factory.makePropertiesManager()
    private lazy var alertService: CoreAlertService = self.factory.makeCoreAlertService()
    private lazy var appStateManager: AppStateManager = self.factory.makeAppStateManager()
    private lazy var vpnGateway: VpnGatewayProtocol = self.factory.makeVpnGateway()
    private weak var viewController: ReloadableViewController?
    
    init( factory: Factory ) {
        self.factory = factory
    }
    
    var startOnBoot: Bool {
        return propertiesManager.startOnBoot
    }
    
    var startMinimized: Bool {
        return propertiesManager.startMinimized
    }
    
    var systemNotifications: Bool {
        return propertiesManager.systemNotifications
    }
    
    var earlyAccess: Bool {
        return propertiesManager.earlyAccess
    }
    
    var unprotectedNetworkNotifications: Bool {
        return propertiesManager.unprotectedNetworkNotifications
    }
    
    var netshieldState: NetShieldType {
        return propertiesManager.netShieldType
    }
    
    var netshieldAvailable: Bool {
        return propertiesManager.featureFlags.isNetShield
    }
    
    // MARK: - Setters
    
    func setViewController(_ vc: ReloadableViewController) {
        self.viewController = vc
    }
    
    func setStartOnBoot(_ enabled: Bool) {
        propertiesManager.startOnBoot = enabled
    }
    
    func setStartMinimized(_ enabled: Bool) {
        propertiesManager.startMinimized = enabled
    }
    
    func setSystemNotifications(_ enabled: Bool) {
        propertiesManager.systemNotifications = enabled
    }
    
    func setEarlyAccess(_ enabled: Bool) {
        propertiesManager.earlyAccess = enabled
    }

    func setUnprotectedNetworkNotifications(_ enabled: Bool) {
        propertiesManager.unprotectedNetworkNotifications = enabled
    }
    
    func setNetshield(_ netShieldType: NetShieldType) {
        
        guard propertiesManager.netShieldType != netShieldType else {
            return
        }
        
        var isConnected = false
        
        switch appStateManager.state {
        case .connected, .connecting:
            isConnected = true
        default:
            break
        }
        
        let userTier = (try? vpnGateway.userTier()) ?? 0
        
        if !isConnected && !netShieldType.isUserTierTooLow(userTier) {
            propertiesManager.netShieldType = netShieldType
            viewController?.reloadView()
            return
        }
        
        let reconnectAlert = ReconnectOnNetshieldChangeAlert(isOn: netShieldType != .off, continueHandler: {
            self.propertiesManager.netShieldType = netShieldType
            self.viewController?.reloadView()
            self.vpnGateway.reconnect(with: netShieldType)
        }, cancelHandler: {
            self.viewController?.reloadView()
        })
        
        switch netShieldType {
        case .off, .level1:
            self.alertService.push(alert: reconnectAlert)
        case .level2:
            guard netShieldType.isUserTierTooLow(userTier) else {
                self.alertService.push(alert: reconnectAlert)
                return
            }
            
            let upgradeAlert = NetShieldRequiresUpgradeAlert(continueHandler: {
                SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
            })
            
            self.alertService.push(alert: upgradeAlert)
            viewController?.reloadView()
        }
    }
}
