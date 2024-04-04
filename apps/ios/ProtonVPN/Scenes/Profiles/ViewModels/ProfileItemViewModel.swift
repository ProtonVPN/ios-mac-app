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
import Dependencies
import ProtonCoreUIFoundations
import LegacyCommon
import Localization
import Strings
import Theme
import Persistence

final class ProfileItemViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    private let profile: Profile
    private let vpnGateway: VpnGatewayProtocol
    private let alertService: AlertService
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let natTypePropertyProvider: NATTypePropertyProvider
    private let safeModePropertyProvider: SafeModePropertyProvider
    private let connectionStatusService: ConnectionStatusService
    private let planService: PlanService
    
    private let userTier: Int
    private let lowestServerTier: Int
    private let underMaintenance: Bool

    var isConnected: Bool {
        if let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connected {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType, withDefaultNATType: natTypePropertyProvider.natType, withDefaultSafeMode: safeModePropertyProvider.safeMode, trigger: .profile)
        }
        return false
    }
    
    private var isConnecting: Bool {
        if let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType, withDefaultNATType: natTypePropertyProvider.natType, withDefaultSafeMode: safeModePropertyProvider.safeMode, trigger: .profile)
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
        return !authorizer.canUseProfile(ofTier: lowestServerTier)
    }

    var connectionChanged: (() -> Void)?
    
    let connectedConnectIcon: Image = IconProvider.powerOff
    
    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return IconProvider.lock
        } else if underMaintenance {
            return IconProvider.wrench
        } else if connectedUiState {
            return connectedConnectIcon
        } else {
            return IconProvider.powerOff
        }
    }
    
    var imageInPlaceOfConnectIcon: UIImage? {
        return isUsersTierTooLow ? Theme.Asset.vpnSubscriptionBadge.image : nil
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
        return underMaintenance ? Localizable.maintenance : Localizable.connect
    }
    
    var alphaOfMainElements: CGFloat {
        return isUsersTierTooLow ? 0.5 : 1.0
    }

    init(profile: Profile, vpnGateway: VpnGatewayProtocol, alertService: AlertService, userTier: Int, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider, connectionStatusService: ConnectionStatusService, planService: PlanService) {
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
            self.lowestServerTier = serverWrapper.server.tier // add unit tests
            self.underMaintenance = serverWrapper.server.underMaintenance
           
        case .fastest(let countryCode): fallthrough
        case .random(let countryCode):
            guard let code = countryCode else {
                self.lowestServerTier = 0
                self.underMaintenance = false
                break
            }

            // In case we won't find such a country in the current list,
            // row be displayed as unavailable
            var minTier = Int.max
            var allServersUnderMaintenance = true

            @Dependency(\.serverRepository) var serverRepository: ServerRepository
            let groups = serverRepository.getGroups(filteredBy: [
                .features(profile.serverType.serverTypeFilter),
                // `.standard(country:)` doesn't work with gateways, but atm we
                // do not support profiles with fastest or random gateway server.
                .kind(.country(code: code)),
            ])
            // There should be only one group matching profile and we want to
            // check its properties instead of traversing all the servers
            if let groupInfo = groups.first {
                minTier = groupInfo.minTier
                allServersUnderMaintenance = groupInfo.isUnderMaintenance
            }

            self.lowestServerTier = minTier
            self.underMaintenance = allServersUnderMaintenance
        }
        
        startObserving()
    }
    
    func connectAction() {
        log.debug("Connect requested by selecting a profile.", category: .connectionConnect, event: .trigger)

        if !authorizer.canUseProfiles {
            log.debug("Connect to profile rejected because user is on free plan", category: .connectionConnect, event: .trigger)
            alertService.push(alert: ProfilesUpsellAlert())
        } else if !authorizer.canUseProfile(ofTier: lowestServerTier) {
            // The user is on a paid plan, but this profile requires a higher user tier
            // This shouldn't really happen unless the user is on the basic plan, or the profile requires visionary tier
            log.warning(
                "Connect rejected because user tier is too low",
                category: .connectionConnect,
                event: .trigger,
                metadata: ["userTier": "\(userTier)", "lowestServerTier": "\(lowestServerTier)"]
            )
            alertService.push(alert: AllCountriesUpsellAlert())
        } else if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert())
        } else if isConnected {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.profile))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Will connect to profile: \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(profile: profile)
            connectionStatusService.presentStatusViewController()
        }
    }
    
    // MARK: Descriptors
    internal func attributedName(forProfile profile: Profile) -> NSAttributedString {
        return profile.name.attributed(withColor: .normalTextColor(), fontSize: 11, alignment: .left)
    }
    
    internal func attributedDescription(forProfile profile: Profile) -> NSAttributedString {
        switch profile.profileType {
        case .system:
            return systemProfileDescriptor(forProfile: profile)
        case .user:
            return userProfileDescriptor(forProfile: profile)
        }
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
            return Localizable.unavailable.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }

        switch profile.serverOffering {
        case .fastest:
            return Localizable.fastestAvailableServer.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        case .random:
            return Localizable.randomAvailableServer.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        case .custom:
            return Localizable.unavailable.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }
    }
    
    private func userProfileDescriptor(forProfile profile: Profile) -> NSAttributedString {
        guard profile.profileType == .user else {
            return Localizable.unavailable.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }

        switch profile.serverOffering {
        case .fastest(let cCode):
            return defaultServerDescriptor(profile.serverType, forCountry: cCode, description: Localizable.fastest)
        case .random(let cCode):
            return defaultServerDescriptor(profile.serverType, forCountry: cCode, description: Localizable.random)
        case .custom(let sWrapper):
            return customServerDescriptor(forModel: sWrapper.server)
        }
    }
    
    private func defaultServerDescriptor(_ serverType: ServerType, forCountry countryCode: String?, description: String) -> NSAttributedString {
        guard let countryCode = countryCode else {
            return description.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        }
        
        let buffer = "  ".attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        let profileDescription = description.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        let countryName = LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
        let attributedCountryName = countryName.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
        let doubleArrow = NSAttributedString.imageAttachment(image: IconProvider.chevronsRight, baselineOffset: -4)

        if serverType == .secureCore {
            return NSAttributedString.concatenate(profileDescription, buffer, doubleArrow, buffer, attributedCountryName)
        } else {
            return NSAttributedString.concatenate(attributedCountryName, buffer, doubleArrow, buffer, profileDescription)
        }
    }
    
    private func customServerDescriptor(forModel serverModel: ServerModel) -> NSAttributedString {
        let doubleArrow = NSAttributedString.imageAttachment(image: IconProvider.chevronsRight, baselineOffset: -4)
        
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
