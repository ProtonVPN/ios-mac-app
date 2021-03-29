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
import vpncore

enum ProfilesSectionListCell {
    case profile(ProfileItemViewModel)
    case footer(ProfilesSectionViewModel)
}

class ProfilesSectionViewModel {
    
    private let vpnGateway: VpnGatewayProtocol
    private let profileManager: ProfileManager
    private let navService: NavigationService
    
    var contentChanged: (() -> Void)?
    
    var cellCount: Int {
        return profileManager.allProfiles.count + 1
    }
    
    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return CoreAppConstants.VpnTiers.free
        }
    }
    
    init(vpnGateway: VpnGatewayProtocol, navService: NavigationService) {
        self.vpnGateway = vpnGateway
        self.navService = navService
        profileManager = ProfileManager.shared
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged),
                                               name: profileManager.contentChanged, object: nil)
    }
    
    func cellHeight(forRow index: Int) -> CGFloat {
        if index < cellCount - 1 {
            return 50
        }
        return 150
    }
    
    func cellModel(forRow index: Int) -> ProfilesSectionListCell {
        if index < cellCount - 1 {
            return .profile(ProfileItemViewModel(profile: profileManager.allProfiles[index], vpnGateway: vpnGateway, userTier: userTier))
        } else {
            return .footer(self)
        }
    }
    
    func createNewProfileAction() {
        navService.openProfiles(ProfilesTab.createNewProfile)
    }
    
    func manageProfilesAction() {
        navService.openProfiles(ProfilesTab.overview)
    }
    
    // MARK: - Private functions
    @objc private func profilesChanged() {
        contentChanged?()
    }
}
