//
//  CountryItemViewModel.swift
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

class CountryItemViewModel {
    
    private let countryModel: CountryModel
    private let serverModels: [ServerModel]
    private let appStateManager: AppStateManager
    private let alertService: AlertService
    private let loginService: LoginService
    private let planService: PlanService
    private var vpnGateway: VpnGatewayProtocol?
    private var serverType: ServerType
    private let connectionStatusService: ConnectionStatusService
    
    private var userTier: Int = CoreAppConstants.VpnTiers.plus
    
    private var isUsersTierTooLow: Bool {
        return userTier < countryModel.lowestTier
    }
    
    let propertiesManager: PropertiesManagerProtocol
    
    var underMaintenance: Bool {
        return !serverModels.contains { !$0.underMaintenance }
    }
    
    private var isConnected: Bool {
        if let vpnGateway = vpnGateway, let activeServer = appStateManager.activeConnection()?.server {
            if vpnGateway.connection == .connected, activeServer.countryCode == countryCode {
                var found = false
                serverModels.forEach { (server) in
                    if activeServer == server {
                        found = true // ensures part of standard or secure core
                    }
                }
                return found
            }
        }
        return false
    }
    
    private var isConnecting: Bool {
        if let vpnGateway = vpnGateway, let activeConnection = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting, case ConnectionRequestType.country(let activeCountryCode, _) = activeConnection.connectionType, activeCountryCode == countryCode {
            return true
        }
        return false
    }
    
    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    var connectionChanged: (() -> Void)?
    
    var countryCode: String {
        return countryModel.countryCode
    }
    
    var countryName: String {
        return LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
    }
    
    var description: String {
        return LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable
    }
    
    var backgroundColor: UIColor {
        return .protonGrey()
    }
    
    var cellHeight: CGFloat {
        return 60
    }
    
    var torAvailable: Bool {
        return countryModel.feature.contains(.tor)
    }
    
    var p2pAvailable: Bool {
        return countryModel.feature.contains(.p2p)
    }
    
    var smartAvailable: Bool {
        return false
    }
    
    var streamingAvailable: Bool {
        return !streamingServices.isEmpty
    }
    
    var isCurrentlyConnected: Bool {
        return isConnected || isConnecting
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
    
    var streamingServices: [VpnStreamingOption] {
        return propertiesManager.streamingServices[countryCode]?["2"] ?? []
    }
    
    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? LocalizedString.upgrade : nil
    }
    
    var alphaOfMainElements: CGFloat {
        if underMaintenance { return 0.25 }
        if isUsersTierTooLow { return 0.5 }
        return 1.0
    }
    
    private lazy var freeServerViewModels: [ServerItemViewModel] = {
        let freeServers = serverModels.filter { (serverModel) -> Bool in
            serverModel.tier == CoreAppConstants.VpnTiers.free
        }
        return serverViewModels(for: freeServers)
    }()
    
    private lazy var basicServerViewModels: [ServerItemViewModel] = {
        let basicServers = serverModels.filter({ (serverModel) -> Bool in
            serverModel.tier == CoreAppConstants.VpnTiers.basic
        })
        return serverViewModels(for: basicServers)
    }()
    
    private lazy var plusServerViewModels: [ServerItemViewModel] = {
        let plusServers = serverModels.filter({ (serverModel) -> Bool in
            serverModel.tier >= CoreAppConstants.VpnTiers.plus
        })
        return serverViewModels(for: plusServers)
    }()
    
    private func serverViewModels(for servers: [ServerModel]) -> [ServerItemViewModel] {
        return servers.map { (server) -> ServerItemViewModel in
            switch serverType {
            case .standard, .p2p, .tor, .unspecified:
                return ServerItemViewModel(serverModel: server, vpnGateway: vpnGateway, appStateManager: appStateManager,
                                           alertService: alertService, loginService: loginService, planService: planService, connectionStatusService: connectionStatusService, propertiesManager: propertiesManager)
            case .secureCore:
                return SecureCoreServerItemViewModel(serverModel: server, vpnGateway: vpnGateway, appStateManager: appStateManager,
                                                     alertService: alertService, loginService: loginService, planService: planService, connectionStatusService: connectionStatusService, propertiesManager: propertiesManager)
            }
        }
    }
    
    private lazy var serverViewModels = { () -> [(tier: Int, viewModels: [ServerItemViewModel])] in
        var serverTypes = [(tier: Int, viewModels: [ServerItemViewModel])]()
        if !freeServerViewModels.isEmpty {
            serverTypes.append((tier: 0, viewModels: freeServerViewModels))
        }
        if !basicServerViewModels.isEmpty {
            serverTypes.append((tier: 1, viewModels: basicServerViewModels))
        }
        if !plusServerViewModels.isEmpty {
            serverTypes.append((tier: 2, viewModels: plusServerViewModels))
        }
        
        serverTypes.sort(by: { (serverGroup1, serverGroup2) -> Bool in
            if userTier >= serverGroup1.tier && userTier >= serverGroup2.tier ||
               userTier < serverGroup1.tier && userTier < serverGroup2.tier { // sort within available then non-available groups
                return serverGroup1.tier > serverGroup2.tier
            } else {
                return serverGroup1.tier < serverGroup2.tier
            }
        })
        
        return serverTypes
    }()
    
    init(countryGroup: CountryGroup, serverType: ServerType, appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol?, alertService: AlertService, loginService: LoginService, planService: PlanService, connectionStatusService: ConnectionStatusService, propertiesManager: PropertiesManagerProtocol) {
        self.countryModel = countryGroup.0
        self.serverModels = countryGroup.1
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.loginService = loginService
        self.serverType = serverType
        self.planService = planService
        self.connectionStatusService = connectionStatusService
        self.propertiesManager = propertiesManager
        startObserving()
    }
    
    func serversCount(for section: Int) -> Int {
        return serverViewModels[section].viewModels.count
    }
    
    func sectionsCount() -> Int {
        return serverViewModels.count
    }
    
    func titleFor(section: Int) -> String {
        let tier = serverViewModels[section].tier
        return CoreAppConstants.serverTierName(forTier: tier) + " (\(self.serversCount(for: section)))"
    }
    
    func isSeverPlus( for section: Int) -> Bool {
        return serverViewModels[section].tier > 1
    }
    
    func cellModel(for row: Int, section: Int) -> ServerItemViewModel {
        return serverViewModels[section].viewModels[row]
    }
    
    func connectAction() {
        guard let vpnGateway = vpnGateway else {
            loginService.presentSignup()
            return
        }
        
        updateTier()
        
        if isUsersTierTooLow {
            planService.presentPlanSelection() 
        } else if underMaintenance {
            alertService.push(alert: MaintenanceAlert(countryName: countryName))
        } else if isConnected {
            vpnGateway.disconnect()
        } else if isConnecting {
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            vpnGateway.connectTo(country: countryCode, ofType: serverType)
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
