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

import Dependencies

import Ergonomics
import LegacyCommon

protocol ProfilesMenuViewModelFactory {
    func makeProfilesMenuViewModel() -> ProfilesMenuViewModel
}

extension DependencyContainer: ProfilesMenuViewModelFactory {
    func makeProfilesMenuViewModel() -> ProfilesMenuViewModel {
        return ProfilesMenuViewModel(
            appSessionManager: makeAppSessionManager(),
            navService: makeNavigationService(),
            alertService: makeCoreAlertService()
        )
    }
}

class ProfilesMenuViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    private let appSessionManager: AppSessionManager
    private let navService: NavigationService
    private let alertService: CoreAlertService

    var contentChanged: (() -> Void)?

    private var notificationTokens: [NotificationToken] = []

    init(
        appSessionManager: AppSessionManager,
        navService: NavigationService,
        alertService: CoreAlertService
    ) {
        self.appSessionManager = appSessionManager
        self.navService = navService
        self.alertService = alertService

        notificationTokens = [
            NotificationCenter.default.addObserver(for: SessionChanged.self, object: appSessionManager, handler: sessionChanged),
            NotificationCenter.default.addObserver(for: VpnKeychain.vpnPlanChanged, object: nil, handler: planChanged),
            NotificationCenter.default.addObserver(for: PropertiesManager.featureFlagsNotification, object: nil, handler: featureFlagsChanged)
        ]
    }

    var areProfilesEnabled: Bool {
        canUserUseProfiles && appSessionManager.sessionStatus == .established
    }

    private var canUserUseProfiles: Bool { authorizer.canUseProfiles }

    func showProfilesUpsellAlert() {
        alertService.push(alert: ProfilesUpsellAlert())
    }
    
    func overviewAction() {
        guard canUserUseProfiles else {
            // The menu shouldn't be visible for free users, so this is just a failsafe
            showProfilesUpsellAlert()
            return
        }
        navService.openProfiles(ProfilesTab.overview)
    }
    
    func createNewProfileAction() {
        guard canUserUseProfiles else {
            // The menu shouldn't be visible for free users, so this is just a failsafe
            showProfilesUpsellAlert()
            return
        }
        navService.openProfiles(ProfilesTab.createNewProfile)
    }
    
    // MARK: - Private functions
    private func sessionChanged(data: SessionChanged.T) {
        contentChanged?()
    }

    private func featureFlagsChanged(notification: Notification) {
        contentChanged?()
    }

    private func planChanged(notification: Notification) {
        contentChanged?()
    }
}
