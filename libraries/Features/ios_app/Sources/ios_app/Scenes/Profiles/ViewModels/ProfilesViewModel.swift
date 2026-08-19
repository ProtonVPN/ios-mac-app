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

import Dependencies
import Domain
import LegacyCommon
import Strings
import UIKit
import VPNAppCore

class ProfilesViewModel {
    @Dependency(\.profileAuthorizer) var profileAuthorizer
    @Dependency(\.upsellManager) private var upsellManager

    private let profileService: ProfileService
    @Dependency(\.profileManager) private var profileManager
    private let connectionStatusService: ConnectionStatusService
    @Dependency(\.credentialsProvider) private var credentialsProvider

    private let sectionTitles = [Localizable.recommended, Localizable.myProfiles]

    private var userTier: VpnTier {
        credentialsProvider.tier
    }

    init(
        profileService: ProfileService,
        connectionStatusService: ConnectionStatusService
    ) {
        self.profileService = profileService
        self.connectionStatusService = connectionStatusService
    }

    func makeCreateProfileViewController() -> UITableViewController? {
        profileService.makeCreateProfileViewController(for: nil)
    }

    func makeEditProfileViewController(for index: Int) -> UITableViewController? {
        let customProfiles = profileManager.customProfiles()
        guard customProfiles.indices.contains(index) else {
            return nil
        }
        return profileService.makeCreateProfileViewController(for: customProfiles[index])
    }

    var headerHeight: CGFloat {
        UIConstants.headerHeight
    }

    var sectionCount: Int {
        2
    }

    func title(for section: Int) -> String {
        sectionTitles[section]
    }

    var cellHeight: CGFloat {
        UIConstants.cellHeight
    }

    var canUseProfiles: Bool {
        profileAuthorizer.canUseProfiles
    }

    func showProfilesUpsellAlert() {
        if canUseProfiles {
            log.error("Tried to show profiles upsell modal, but profiles are usable", category: .userPlan)
            return
        }
        upsellManager.present(.profiles)
    }

    func cellCount(for section: Int) -> Int {
        switch section {
        case 0:
            2
        default:
            profileManager.customProfiles().count
        }
    }

    func defaultCellModel(for row: Int) -> DefaultProfileViewModel {
        let serverOffering = row == 0 ? ServerOffering.fastest(nil) : ServerOffering.random(nil)
        return DefaultProfileViewModel(serverOffering: serverOffering)
    }

    func cellModel(for index: Int) -> ProfileItemViewModel? {
        let customProfiles = profileManager.customProfiles()
        guard customProfiles.indices.contains(index) else {
            return nil
        }
        return ProfileItemViewModel(
            profile: customProfiles[index],
            userTier: userTier
        )
    }

    func deleteProfile(for index: Int) {
        let customProfiles = profileManager.customProfiles()
        if customProfiles.indices.contains(index) {
            profileManager.deleteProfile(customProfiles[index])
        }
    }

    func reloadData() {
        profileManager.refreshProfiles()
    }
}
