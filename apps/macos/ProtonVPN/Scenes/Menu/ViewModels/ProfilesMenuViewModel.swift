//
//  ProfilesMenuViewModel.swift
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

protocol ProfilesMenuViewModelFactory {
    func makeProfilesMenuViewModel() -> ProfilesMenuViewModel
}

extension DependencyContainer: ProfilesMenuViewModelFactory {
    func makeProfilesMenuViewModel() -> ProfilesMenuViewModel {
        return ProfilesMenuViewModel(appSessionManager: makeAppSessionManager(), navService: makeNavigationService())
    }
}

class ProfilesMenuViewModel {
    
    private let appSessionManager: AppSessionManager
    private let navService: NavigationService
    
    var contentChanged: (() -> Void)?

    private var notificationTokens: [NotificationToken] = []

    init(appSessionManager: AppSessionManager, navService: NavigationService) {
        self.appSessionManager = appSessionManager
        self.navService = navService
        
        notificationTokens.append(NotificationCenter.default.addObserver(for: SessionChanged.self, object: appSessionManager, handler: sessionChanged))
    }
    
    var isOverviewEnabled: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    var isCreateNewProfileEnabled: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    func overviewAction() {
        navService.openProfiles(ProfilesTab.overview)
    }
    
    func createNewProfileAction() {
        navService.openProfiles(ProfilesTab.createNewProfile)
    }
    
    // MARK: - Private functions
    private func sessionChanged(data: SessionChanged.T) {
        contentChanged?()
    }
}
