//
//  ServerItemViewModel.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit
import vpncore

class ServerItemViewModel {
    
    fileprivate let serverModel: ServerModel
    fileprivate var vpnGateway: VpnGatewayProtocol?
    fileprivate let appStateManager: AppStateManager
    fileprivate let propertiesManager: PropertiesManagerProtocol
    private let alertService: AlertService
    private let connectionStatusService: ConnectionStatusService
    private let planService: PlanService
    
    private var userTier: Int = CoreAppConstants.VpnTiers.plus
    
    var isUsersTierTooLow: Bool {
        return userTier < serverModel.tier
    }
    
    let underMaintenance: Bool
    
    private var isConnected: Bool {
        if let vpnGateway = vpnGateway, let activeServer = appStateManager.activeConnection()?.server {
            if vpnGateway.connection == .connected, activeServer.id == serverModel.id {
                return true
            }
        }
        return false
    }
    
    private var isConnecting: Bool {
        if let vpnGateway = vpnGateway, let activeConnection = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting, case ConnectionRequestType.country(_, let countryRequestType) = activeConnection.connectionType, case CountryConnectionRequestType.server(let activeServer) = countryRequestType, activeServer == serverModel {
            return true
        }
        return false
    }
    
    var viaCountry: (name: String, code: String)? {
        return nil
    }
    
    var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    fileprivate var canConnect: Bool {
        return !isUsersTierTooLow && !underMaintenance
    }
    
    let backgroundColor = UIColor.backgroundColor()
    
    fileprivate(set) var isCountryConnected: Bool = false
    var connectionChanged: (() -> Void)?
    var countryConnectionChanged: Notification.Name?
    
    // MARK: First line in the TableCell
    
    var description: String { return serverModel.name }
    
    var city: String {
        return serverModel.city ?? ""
    }

    var loadValue: String {
        return "\(serverModel.load)%"
    }
    
    var loadColor: UIColor {
        if serverModel.load > 90 {
            return .notificationErrorColor()
        } else if serverModel.load > 75 {
            return .notificationWarningColor()
        } else {
            return .notificationOKColor()
        }
    }

    var torAvailable: Bool {
        return serverModel.feature.contains(.tor)
    }
    
    var p2pAvailable: Bool {
        return serverModel.feature.contains(.p2p)
    }
    
    var isSmartAvailable: Bool {
        return serverModel.isVirtual
    }
    
    var streamingAvailable: Bool {
        let tier = String(serverModel.tier)
        return propertiesManager.streamingServices[serverModel.countryCode]?[tier] != nil
    }
    
    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return #imageLiteral(resourceName: "con-locked")
        } else if underMaintenance {
            return #imageLiteral(resourceName: "ic_maintenance")
        } else {
            return #imageLiteral(resourceName: "con-available")
        }
    }
    
    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? LocalizedString.upgrade : nil
    }
    
    var alphaOfMainElements: CGFloat {
        if underMaintenance { return 0.25 }
        if isUsersTierTooLow { return 0.5 }
        return 1.0
    }
    
    init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol?, appStateManager: AppStateManager, alertService: AlertService, connectionStatusService: ConnectionStatusService, propertiesManager: PropertiesManagerProtocol, planService: PlanService) {
        self.serverModel = serverModel
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.underMaintenance = serverModel.underMaintenance
        self.alertService = alertService
        self.connectionStatusService = connectionStatusService
        self.propertiesManager = propertiesManager
        self.planService = planService
        let activeConnection = appStateManager.activeConnection()
        
        isCountryConnected = vpnGateway?.connection == .connected
            && activeConnection?.server.isSecureCore == false
            && activeConnection?.server.countryCode == serverModel.countryCode
        
        if canConnect {
            startObserving()
        }
    }
    
    func connectAction() {
        guard let vpnGateway = vpnGateway else {
            return
        }
        
        updateTier()
        
        if underMaintenance {
            alertService.push(alert: MaintenanceAlert(forSpecificCountry: nil))
        } else if isUsersTierTooLow {
            planService.presentPlanSelection()
        } else if isConnected {
            vpnGateway.disconnect()
        } else if isConnecting {
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            vpnGateway.connectTo(server: serverModel)
            connectionStatusService.presentStatusViewController()
        }
    }
    
    func updateTier() {
        do {
            if let vpnGateway = vpnGateway {
                userTier = try vpnGateway.userTier()
            } else { // not logged in
                userTier = CoreAppConstants.VpnTiers.plus
            }
        } catch {
            userTier = CoreAppConstants.VpnTiers.free
        }
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}

// MARK: - SecureCoreServerItemViewModel subclass
class SecureCoreServerItemViewModel: ServerItemViewModel {
        
    override var viaCountry: (name: String, code: String)? {
        return serverModel.isSecureCore ? (serverModel.entryCountry, serverModel.entryCountryCode) : nil
    }
    
    override init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol?, appStateManager: AppStateManager, alertService: AlertService, connectionStatusService: ConnectionStatusService, propertiesManager: PropertiesManagerProtocol, planService: PlanService) {
        super.init(serverModel: serverModel, vpnGateway: vpnGateway, appStateManager: appStateManager, alertService: alertService, connectionStatusService: connectionStatusService, propertiesManager: propertiesManager, planService: planService)
        
        let activeConnection = appStateManager.activeConnection()
        
        isCountryConnected = vpnGateway?.connection == .connected
            && activeConnection?.server.hasSecureCore == true
            && activeConnection?.server.countryCode == serverModel.countryCode
    }
    
    override fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
}
