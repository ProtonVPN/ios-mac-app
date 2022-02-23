//
//  ProfileItemViewModel.swift
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

import Foundation
import UIKit
import vpncore

final class ProfileItemViewModel {
    
    private let profile: Profile
    private let vpnGateway: VpnGatewayProtocol?
    private let alertService: AlertService
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let natTypePropertyProvider: NATTypePropertyProvider
    private let safeModePropertyProvider: SafeModePropertyProvider
    private let connectionStatusService: ConnectionStatusService
    private let planService: PlanService
    
    private let userTier: Int
    private let lowestSeverTier: Int
    private let underMaintenance: Bool
    
    private var isConnected: Bool {
        if let vpnGateway = vpnGateway, let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connected {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType, withDefaultNATType: natTypePropertyProvider.natType, withDefaultSafeMode: safeModePropertyProvider.safeMode)
        }
        return false
    }
    
    private var isConnecting: Bool {
        if let vpnGateway = vpnGateway, let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType, withDefaultNATType: natTypePropertyProvider.natType, withDefaultSafeMode: safeModePropertyProvider.safeMode)
        }
        return false
    }
    
    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    private var canConnect: Bool {
        return !underMaintenance
    }
    
    private var isUsersTierTooLow: Bool {
        return userTier < lowestSeverTier
    }
    
    var connectionChanged: (() -> Void)?
    
    let connectedConnectIcon = UIImage(named: "con-connected")
    
    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return UIImage(named: "con-locked")
        } else if underMaintenance {
            return UIImage(named: "con-unavailable")
        } else if connectedUiState {
            return connectedConnectIcon
        } else {
            return UIImage(named: "con-available")
        }
    }
    
    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? LocalizedString.upgrade : nil
    }
    
    var icon: ProfileIcon {
        return profile.profileIcon
    }
    
    var name: NSAttributedString {
        return attributedName(forProfile: profile)
    }
    
    var description: NSAttributedString {
        return attributedDescription(forProfile: profile)
    }
    
    var connectButtonTitle: String {
        return underMaintenance ? LocalizedString.maintenance : LocalizedString.connect
    }
    
    var alphaOfMainElements: CGFloat {
        return isUsersTierTooLow ? 0.5 : 1.0
    }
    
    init(profile: Profile, vpnGateway: VpnGatewayProtocol?, alertService: AlertService, userTier: Int, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider, connectionStatusService: ConnectionStatusService, planService: PlanService) {
        self.profile = profile
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.userTier = userTier
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.connectionStatusService = connectionStatusService
        self.planService = planService

        switch profile.serverOffering {
        case .custom(let serverWrapper):
            self.lowestSeverTier = serverWrapper.server.tier
            self.underMaintenance = serverWrapper.server.underMaintenance
           
        case .fastest(let countryCode): fallthrough
        case .random(let countryCode):
            guard let code = countryCode else {
                self.lowestSeverTier = 0
                self.underMaintenance = false
                break
            }
            
            let serverManager = ServerManagerImplementation.instance(forTier: userTier, serverStorage: ServerStorageConcrete())
            
            var minTier = Int.max
            var allServersUnderMaintenance = true
            serverManager.servers.filter { (server) -> Bool in
                return server.countryCode == code && server.serverType == profile.serverType
            }.forEach { (server) in
                if minTier > server.tier {
                    minTier = server.tier
                }
                if !server.underMaintenance {
                    allServersUnderMaintenance = false
                }
            }
            self.lowestSeverTier = minTier
            self.underMaintenance = allServersUnderMaintenance
        }
        
        startObserving()
    }
    
    func connectAction() {
        guard let vpnGateway = vpnGateway else {
            return
        }
        
        log.debug("Connect requested by selecting a profile.", category: .connectionConnect, event: .trigger)

        if profile.connectionProtocol == ConnectionProtocol.vpnProtocol(.wireGuard), case let .custom(server) = profile.serverOffering, !server.server.ips.contains(where: { $0.supportsWireguard }) {
            log.debug("Won't connect because no wireguard server can be found for this profile.", category: .connectionConnect, event: .trigger)
            alertService.push(alert: WireguardProfileErrorAlert())
            return
        }
        
        if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            alertService.push(alert: AllCountriesUpsellAlert())
        } else if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert())
        } else if isConnected {
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            log.debug("Will connect to profile: \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(profile: profile)
            connectionStatusService.presentStatusViewController()
        }
    }
    
    // MARK: Descriptors
    internal func attributedName(forProfile profile: Profile) -> NSAttributedString {
        var textColor: UIColor = .normalTextColor()
        if case let ProfileIcon.circle(color) = profile.profileIcon {
            textColor = UIColor(rgbHex: color)
        }
        return profile.name.attributed(withColor: textColor, fontSize: 11, alignment: .left)
    }
    
    internal func attributedDescription(forProfile profile: Profile) -> NSAttributedString {
        let description: NSAttributedString
        switch profile.profileType {
        case .system:
            description = systemProfileDescriptor(forProfile: profile)
        case .user:
            description = userProfileDescriptor(forProfile: profile)
        }
        return description
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            connectionChanged()
        }
    }
    
    private func systemProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .system else {
            return LocalizedString.unavailable.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest:
            description = LocalizedString.fastestAvailableServer.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        case .random:
            description = LocalizedString.randomAvailableServer.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        case .custom:
            description = LocalizedString.unavailable.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }
        return description
    }
    
    private func userProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .user else {
            return LocalizedString.unavailable.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }
        
        let description: NSAttributedString
        switch profile.serverOffering {
        case .fastest(let cCode):
            description = defaultServerDescriptor(profile.serverType, forCountry: cCode, description: LocalizedString.fastest)
        case .random(let cCode):
            description = defaultServerDescriptor(profile.serverType, forCountry: cCode, description: LocalizedString.random)
        case .custom(let sWrapper):
            description = customServerDescriptor(forModel: sWrapper.server)
        }
        return description
    }
    
    private func defaultServerDescriptor(_ serverType: ServerType, forCountry countryCode: String?, description: String) -> NSAttributedString {
        guard let countryCode = countryCode else {
            return description.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }
        
        let buffer = "  ".attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        let profileDescription = description.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        let countryName = LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
        let attributedCountryName = countryName.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        let doubleArrow = NSAttributedString.imageAttachment(named: "double-arrow-right-white", width: 10, height: 10)!
        
        let description: NSAttributedString
        if serverType == .secureCore {
            description = NSAttributedString.concatenate(profileDescription, buffer, doubleArrow, buffer, attributedCountryName)
        } else {
            description = NSAttributedString.concatenate(attributedCountryName, buffer, doubleArrow, buffer, profileDescription)
        }
        return description
    }
    
    private func customServerDescriptor(forModel serverModel: ServerModel) -> NSAttributedString {
        let doubleArrow = NSAttributedString.imageAttachment(named: "double-arrow-right-white", width: 10, height: 10)!
        
        if serverModel.isSecureCore {
            let entryCountry = (serverModel.entryCountry + "  ").attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
            let exitCountry = ("  " + serverModel.exitCountry + "  ").attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
            return NSAttributedString.concatenate(entryCountry, doubleArrow, exitCountry)
        } else {
            let countryName = (serverModel.country + "  ").attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
            let serverName = ("  " + serverModel.name).attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
            return NSAttributedString.concatenate(countryName, doubleArrow, serverName)
        }
    }
}
