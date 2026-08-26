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
import Combine
import Dependencies
import Domain
import Sharing
import VPNAppCore

protocol ProfilesMenuViewModelFactory {
    func makeProfilesMenuViewModel() -> ProfilesMenuViewModel
}

extension DependencyContainer: ProfilesMenuViewModelFactory {
    func makeProfilesMenuViewModel() -> ProfilesMenuViewModel {
        ProfilesMenuViewModel(
            navService: makeNavigationService()
        )
    }
}

class ProfilesMenuViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    private let navService: NavigationService
    @Dependency(\.upsellManager) private var upsellManager
    @Dependency(\.planChangeClient) private var planChangeClient

    var contentChanged: (() -> Void)?

    private var planChangeObservation: Task<Void, Never>?

    @SharedReader(.sessionStatus) private var sessionStatus: SessionStatus
    @SharedReader(.featureFlags) private var featureFlags: FeatureFlags
    private var cancellables = Set<AnyCancellable>()

    init(
        navService: NavigationService
    ) {
        self.navService = navService

        // A plan change can hand the user profiles or take them away, so the menu is rebuilt.
        let planChanges = planChangeClient.events()
        self.planChangeObservation = Task { @MainActor [weak self] in
            for await _ in planChanges {
                self?.contentChanged?()
            }
        }

        $featureFlags.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.contentChanged?() }
            .store(in: &cancellables)

        $sessionStatus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.contentChanged?() }
            .store(in: &cancellables)
    }

    var areProfilesEnabled: Bool {
        canUserUseProfiles && sessionStatus == .established
    }

    private var canUserUseProfiles: Bool {
        authorizer.canUseProfiles
    }

    func showProfilesUpsellAlert() {
        upsellManager.present(.profiles)
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

    deinit {
        planChangeObservation?.cancel()
    }
}
