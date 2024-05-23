//
//  OverviewViewModel.swift
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

import Cocoa
import LegacyCommon

final class OverviewViewModel {
    
    private let profileManager: ProfileManager
    private let vpnGateway: VpnGatewayProtocol
    private let sessionService: SessionService
    
    var contentChanged: (() -> Void)?
    var createNewProfile: (() -> Void)?
    var editProfile: ((Profile) -> Void)?
    
    init(vpnGateway: VpnGatewayProtocol, profileManager: ProfileManager, sessionService: SessionService) {
        self.vpnGateway = vpnGateway
        self.profileManager = profileManager
        self.sessionService = sessionService
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged),
                                               name: profileManager.contentChanged, object: nil)
    }
    
    @objc private func profilesChanged() {
        contentChanged?()
    }
    
    var cellHeight: CGFloat {
        return 50.0
    }
    
    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return .freeTier
        }
    }
    
    var cellCount: Int {
        return profileManager.allProfiles.count
    }
    
    func cellModel(forIndex index: Int) -> OverviewItemViewModel {
        return OverviewItemViewModel(profile: profileManager.allProfiles[index],
                                     editProfile: editProfile,
                                     profileManager: profileManager,
                                     vpnGateway: vpnGateway,
                                     userTier: userTier,
                                     sessionService: sessionService
        )
    }
    
    func createNewProfileAction() {
        createNewProfile?()
    }
}
