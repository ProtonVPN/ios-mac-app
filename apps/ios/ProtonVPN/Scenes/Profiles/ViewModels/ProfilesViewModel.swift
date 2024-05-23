//
//  ProfilesViewModel.swift
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
import Dependencies
import LegacyCommon
import Strings

class ProfilesViewModel {
    typealias Factory = ProfileService

    @Dependency(\.profileAuthorizer) var profileAuthorizer
    private let factory: Factory
    private let alertService: AlertService
    private var vpnGateway: VpnGatewayProtocol
    private var profileManager: ProfileManager?
    private let propertiesManager: PropertiesManagerProtocol
    private let connectionStatusService: ConnectionStatusService
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let natTypePropertyProvider: NATTypePropertyProvider
    private let safeModePropertyProvider: SafeModePropertyProvider
    private let planService: PlanService

    private let sectionTitles = [Localizable.recommended, Localizable.myProfiles]

    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return .freeTier
        }
    }
    
    init(vpnGateway: VpnGatewayProtocol, factory: Factory, alertService: AlertService, propertiesManager: PropertiesManagerProtocol, connectionStatusService: ConnectionStatusService, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider, planService: PlanService, profileManager: ProfileManager) {
        self.vpnGateway = vpnGateway
        self.factory = factory
        self.alertService = alertService
        self.propertiesManager = propertiesManager
        self.connectionStatusService = connectionStatusService
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.planService = planService
        self.profileManager = profileManager
    }
    
    func makeCreateProfileViewController() -> UITableViewController? {
        return factory.makeCreateProfileViewController(for: nil)
    }
    
    func makeEditProfileViewController(for index: Int) -> UITableViewController? {
        return factory.makeCreateProfileViewController(for: profileManager?.customProfiles[index])
    }
    
    var headerHeight: CGFloat {
        return UIConstants.headerHeight
    }
    
    var sectionCount: Int {
        return 2
    }
    
    func title(for section: Int) -> String {
        return sectionTitles[section]
    }
    
    var cellHeight: CGFloat {
        return UIConstants.cellHeight
    }

    var canUseProfiles: Bool { profileAuthorizer.canUseProfiles }

    func showProfilesUpsellAlert() {
        if canUseProfiles {
            log.error("Tried to show profiles upsell modal, but profiles are usable", category: .userPlan)
            return
        }
        alertService.push(alert: ProfilesUpsellAlert())
    }
    
    func cellCount(for section: Int) -> Int {
        switch section {
        case 0:
            return 2 // fastest and random
        default:
            return profileManager?.customProfiles.count ?? 0
        }
    }
    
    func defaultCellModel(for row: Int) -> DefaultProfileViewModel {
        let serverOffering = row == 0 ? ServerOffering.fastest(nil) : ServerOffering.random(nil)
        return DefaultProfileViewModel(serverOffering: serverOffering,
                                       vpnGateway: vpnGateway,
                                       alertService: alertService,
                                       propertiesManager: propertiesManager,
                                       connectionStatusService: connectionStatusService,
                                       netShieldPropertyProvider: netShieldPropertyProvider,
                                       natTypePropertyProvider: natTypePropertyProvider,
                                       safeModePropertyProvider: safeModePropertyProvider)
    }
    
    func cellModel(for index: Int) -> ProfileItemViewModel? {
        if let profile = profileManager?.customProfiles[index] {
            return ProfileItemViewModel(profile: profile,
                                        vpnGateway: vpnGateway,
                                        alertService: alertService,
                                        userTier: userTier,
                                        netShieldPropertyProvider: netShieldPropertyProvider,
                                        natTypePropertyProvider: natTypePropertyProvider,
                                        safeModePropertyProvider: safeModePropertyProvider,
                                        connectionStatusService: connectionStatusService,
                                        planService: planService)
        }
        return nil
    }
    
    func deleteProfile(for index: Int) {
        if let profile = profileManager?.customProfiles[index],
            let profileManager = profileManager {
                profileManager.deleteProfile(profile)
        }
    }
    
    func reloadData() {
        profileManager?.refreshProfiles()
    }
}
