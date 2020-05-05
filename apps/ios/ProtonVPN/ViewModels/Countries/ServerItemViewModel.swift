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
    private let alertService: AlertService
    private let loginService: LoginService
    private var planService: PlanService
    
    private let userTier: Int
    fileprivate var isUsersTierTooLow: Bool {
        return userTier < serverModel.tier
    }
    
    fileprivate let underMaintenance: Bool
    
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
    
    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    fileprivate var canConnect: Bool {
        return !isUsersTierTooLow && !underMaintenance
    }
    
    let backgroundColor = UIColor.protonGrey()
    
    fileprivate(set) var isCountryConnected: Bool = false
    var connectionChanged: (() -> Void)?
    var countryConnectionChanged: Notification.Name?
    
    // MARK: First line in the TableCell
    var description: NSAttributedString {
        return serverModel.name.attributed(withColor: .protonWhite(), fontSize: 16.5, alignment: .left)
    }
    
    var city: NSAttributedString {
        return (serverModel.city ?? "").attributed(withColor: .protonWhite(), fontSize: 16.5, alignment: .left)
    }
    
    // MARK: Second line in the TableCell
    var loadLabel: NSAttributedString {
        return (LocalizedString.load + ":").attributed(withColor: .protonFontLightGrey(), fontSize: 14.5, alignment: .left)
    }
    
    var loadValue: NSAttributedString {
        return "\(serverModel.load)%".attributed(withColor: .protonFontLightGrey(), fontSize: 14.5, alignment: .left)
    }
    
    var connectionProperties: NSAttributedString {
        var string: String = ""
        if serverModel.feature.contains(.tor) {
            string.append(LocalizedString.tor)
        }
        if serverModel.feature.contains(.p2p) {
            if !string.isEmpty {
                string.append(" | ")
            }
            string.append(LocalizedString.p2p)
        }
        return string.attributed(withColor: .protonFontLightGrey(), fontSize: 12, alignment: .left)
    }
    
    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return UIImage(named: "con-locked")
        } else if underMaintenance {
            return UIImage(named: "con-unavailable")
        } else if connectedUiState {
            return UIImage(named: "con-connected")
        } else {
            return UIImage(named: "con-available")
        }
    }
    
    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? LocalizedString.upgrade : nil
    }
    
    var alphaOfMainElements: CGFloat {
        return isUsersTierTooLow ? 0.5 : 1.0
    }

    var secondaryDescription: NSAttributedString {
        return formSecondaryDescription()
    }
    
    var keywordIcons: [(UIImage, String)] {
        var icons = [(UIImage, String)]()
        
        if serverModel.tier >= 2 {
            icons.append((#imageLiteral(resourceName: "protonvpn-server-premium-list"), LocalizedString.premiumDescription))
        }
        if serverModel.feature.contains(.tor) {
            icons.append((#imageLiteral(resourceName: "protonvpn-server-tor-list"), LocalizedString.torDescription))
        }
        if serverModel.feature.contains(.p2p) {
            icons.append((#imageLiteral(resourceName: "protonvpn-server-p2p-list"), LocalizedString.p2pDescription))
        }
        
        return icons
    }
    
    init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol?, appStateManager: AppStateManager, alertService: AlertService, loginService: LoginService, planService: PlanService) {
        self.serverModel = serverModel
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.underMaintenance = serverModel.underMaintenance
        self.alertService = alertService
        self.loginService = loginService
        self.planService = planService
        
        let activeConnection = appStateManager.activeConnection()
        
        isCountryConnected = vpnGateway?.connection == .connected
            && activeConnection?.server.isSecureCore == false
            && activeConnection?.server.countryCode == serverModel.countryCode
        
        do {
            if let vpnGateway = vpnGateway {
                userTier = try vpnGateway.userTier()
            } else { // not logged in
                userTier = CoreAppConstants.VpnTiers.visionary
            }
        } catch {
            userTier = CoreAppConstants.VpnTiers.free
        }
        
        if canConnect {
            startObserving()
        }
    }
    
    func connectAction() {
        guard let vpnGateway = vpnGateway else {
            loginService.presentSignup()
            return
        }
        
        if isUsersTierTooLow {
            planService.presentPlanSelection()
        } else if underMaintenance {
            alertService.push(alert: MaintenanceAlert(forSpecificCountry: nil))
        } else if isConnected {
            vpnGateway.disconnect()
        } else if isConnecting {
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            vpnGateway.connectTo(server: serverModel)
        }
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func formSecondaryDescription() -> NSAttributedString {
        let description: NSAttributedString
        if isUsersTierTooLow {
            description = LocalizedString.upgrade.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .right)
        } else if underMaintenance {
            description = LocalizedString.maintenance.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .right)
        } else {
            description = (serverModel.isFree ? "" : serverModel.ips[0].exitIp).attributed(withColor: .protonWhite(), fontSize: 14, alignment: .right)
        }
        
        return description
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
    
    var via: NSAttributedString {
        return "via".attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
    }
    
    var countryCode: String {
        return serverModel.isSecureCore ? serverModel.entryCountryCode : ""
    }
    
    override var description: NSAttributedString {
        return formDescription()
    }
    
    override var secondaryDescription: NSAttributedString {
        return formSecondaryDescription()
    }
    
    override init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol?, appStateManager: AppStateManager, alertService: AlertService, loginService: LoginService, planService: PlanService) {
        super.init(serverModel: serverModel, vpnGateway: vpnGateway, appStateManager: appStateManager, alertService: alertService, loginService: loginService, planService: planService)
        
        let activeConnection = appStateManager.activeConnection()
        
        isCountryConnected = vpnGateway?.connection == .connected
            && activeConnection?.server.hasSecureCore == true
            && activeConnection?.server.countryCode == serverModel.countryCode
    }
    
    override fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func formDescription() -> NSAttributedString {
        if !serverModel.isSecureCore {
            return LocalizedString.unavailable.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
        let country: NSAttributedString
        country = String(format: LocalizedString.viaCountry, serverModel.entryCountry).attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        return country
    }
    
    private func formSecondaryDescription() -> NSAttributedString {
        let description: NSAttributedString
        
        if isUsersTierTooLow {
            description = LocalizedString.upgrade.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .right)
        } else if underMaintenance {
            description = LocalizedString.maintenance.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .right)
        } else {
            description = "".attributed(withColor: .protonWhite(), fontSize: 14, alignment: .right)
        }
        
        return description
    }
}
