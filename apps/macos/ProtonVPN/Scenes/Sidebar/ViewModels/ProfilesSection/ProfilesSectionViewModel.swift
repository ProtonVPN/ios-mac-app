//
//  ProfilesSectionViewModel.swift
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
import Dependencies
import LegacyCommon

enum ProfilesSectionListCell {
    case profile(ProfileItemViewModel)
    case footer(ProfilesSectionViewModel)
}

class ProfilesSectionViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    private let vpnGateway: VpnGatewayProtocol
    private let profileManager: ProfileManager
    private let navService: NavigationService
    private let alertService: CoreAlertService
    private let sysexManager: SystemExtensionManager

    var contentChanged: (() -> Void)?

    var cellCount: Int {
        return profileManager.allProfiles.count + 1
    }
    
    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return .freeTier
        }
    }
    
    init(vpnGateway: VpnGatewayProtocol, navService: NavigationService, alertService: CoreAlertService, profileManager: ProfileManager, protocolChangeNotifications: [Notification.Name], sysexManager: SystemExtensionManager) {
        self.vpnGateway = vpnGateway
        self.navService = navService
        self.alertService = alertService
        self.profileManager = profileManager
        self.sysexManager = sysexManager
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged), name: profileManager.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged), name: VpnKeychain.vpnPlanChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged), name: PropertiesManager.featureFlagsNotification, object: nil)
        for notificationName in protocolChangeNotifications {
            NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged), name: notificationName, object: nil)
        }
        
    }
    
    func cellHeight(forRow index: Int) -> CGFloat {
        if index < cellCount - 1 {
            return 50
        }
        return 150
    }
    
    func cellModel(forRow index: Int) -> ProfilesSectionListCell {
        if index < cellCount - 1 {
            return .profile(ProfileItemViewModel(profile: profileManager.allProfiles[index], vpnGateway: vpnGateway, alertService: alertService, sysexManager: sysexManager))
        } else {
            return .footer(self)
        }
    }

    var canUseProfiles: Bool { authorizer.canUseProfiles }

    private func showProfilesUpsellAlert() {
        alertService.push(alert: ProfilesUpsellAlert())
    }
    
    func createNewProfileAction() {
        guard canUseProfiles else {
            showProfilesUpsellAlert()
            return
        }
        navService.openProfiles(ProfilesTab.createNewProfile)
    }
    
    func manageProfilesAction() {
        guard canUseProfiles else {
            showProfilesUpsellAlert()
            return
        }
        navService.openProfiles(ProfilesTab.overview)
    }
    
    // MARK: - Private functions
    @objc private func profilesChanged() {
        contentChanged?()
    }
}
