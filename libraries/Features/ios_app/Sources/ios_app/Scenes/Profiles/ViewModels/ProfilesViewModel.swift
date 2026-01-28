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
import ProtonCoreFeatureFlags
import UIKit

import Domain
import LegacyCommon
import Strings
import VPNAppCore

class ProfilesViewModel {
    typealias Factory = CoreAlertServiceFactory & VpnGatewayFactory

    @Dependency(\.profileAuthorizer) var profileAuthorizer
    private let factory: Factory
    private lazy var alertService = factory.makeCoreAlertService()
    private lazy var vpnGateway = factory.makeVpnGateway()

    private let profileService: ProfileService
    private var profileManager: ProfileManager?
    private let connectionStatusService: ConnectionStatusService
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    private let sectionTitles = [Localizable.recommended, Localizable.myProfiles]

    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return .freeTier
        }
    }

    init(
        factory: Factory,
        profileService: ProfileService,
        connectionStatusService: ConnectionStatusService,
        profileManager: ProfileManager
    ) {
        self.factory = factory
        self.profileService = profileService
        self.connectionStatusService = connectionStatusService
        self.profileManager = profileManager
    }

    func makeCreateProfileViewController() -> UITableViewController? {
        profileService.makeCreateProfileViewController(for: nil)
    }

    func makeEditProfileViewController(for index: Int) -> UITableViewController? {
        profileService.makeCreateProfileViewController(for: profileManager?.customProfiles[index])
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
            2
        default:
            profileManager?.customProfiles.count ?? 0
        }
    }

    func defaultCellModel(for row: Int) -> DefaultProfileViewModel {
        let serverOffering = row == 0 ? ServerOffering.fastest(nil) : ServerOffering.random(nil)
        return DefaultProfileViewModel(
            serverOffering: serverOffering,
            vpnGateway: vpnGateway,
            alertService: alertService,
            connectionStatusService: connectionStatusService
        )
    }

    func cellModel(for index: Int) -> ProfileItemViewModel? {
        if let profile = profileManager?.customProfiles[index] {
            return ProfileItemViewModel(
                profile: profile,
                vpnGateway: vpnGateway,
                alertService: alertService,
                userTier: userTier,
                connectionStatusService: connectionStatusService
            )
        }
        return nil
    }

    func deleteProfile(for index: Int) {
        if let profile = profileManager?.customProfiles[index],
           let profileManager {
            profileManager.deleteProfile(profile)
        }
    }

    func reloadData() {
        profileManager?.refreshProfiles()
    }
}
