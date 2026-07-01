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
import ProtonCoreFeatureFlags
import Strings
import UIKit
import VPNAppCore

class ProfilesViewModel {
    @Dependency(\.profileAuthorizer) var profileAuthorizer
    @Dependency(\.upsellManager) private var upsellManager

    private let profileService: ProfileService
    @Dependency(\.profileManager) private var profileManager
    private let connectionStatusService: ConnectionStatusService
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.vpnKeychain) private var vpnKeychain

    private let sectionTitles = [Localizable.recommended, Localizable.myProfiles]

    private var userTier: Int {
        do {
            return try vpnKeychain.fetchCached().maxTier
        } catch {
            return .freeTier
        }
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
        if profileManager.customProfiles().indices.contains(index) {
            let profile = profileManager.customProfiles()[index]
            return profileService.makeCreateProfileViewController(for: profile)
        }
        return nil
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
        return DefaultProfileViewModel(
            serverOffering: serverOffering,
            connectionStatusService: connectionStatusService
        )
    }

    func cellModel(for index: Int) -> ProfileItemViewModel? {
        if profileManager.customProfiles().indices.contains(index) {
            let profile = profileManager.customProfiles()[index]
            return ProfileItemViewModel(
                profile: profile,
                userTier: userTier,
                connectionStatusService: connectionStatusService
            )
        }
        return nil
    }

    func deleteProfile(for index: Int) {
        if profileManager.customProfiles().indices.contains(index) {
            let profile = profileManager.customProfiles()[index]
            profileManager.deleteProfile(profile)
        }
    }

    func reloadData() {
        profileManager.refreshProfiles()
    }
}
