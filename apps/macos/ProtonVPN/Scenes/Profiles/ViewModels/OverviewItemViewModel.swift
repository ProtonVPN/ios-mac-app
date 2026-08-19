//
//  OverviewItemViewModel.swift
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
import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Strings
import VPNAppCore

final class OverviewItemViewModel: AbstractProfileViewModel {
    private let editProfile: ((Profile) -> Void)?
    @Dependency(\.profileManager) private var profileManager
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.coreAlertService) private var coreAlertService

    @Dependency(\.sessionService) private var sessionService

    var canConnect: Bool {
        !underMaintenance
    }

    var icon: ProfileIcon {
        profile.profileIcon
    }

    var name: NSAttributedString {
        attributedName(forProfile: profile)
    }

    var description: NSAttributedString {
        attributedDescription(forProfile: profile)
    }

    var isSystemProfile: Bool {
        profile.profileType == .system
    }

    init(profile: Profile, editProfile: ((Profile) -> Void)?, userTier: VpnTier) {
        self.editProfile = editProfile
        super.init(profile: profile, userTier: userTier)
    }

    func connectAction(completion: () -> Void) {
        log.debug("Connect requested by pressing Connect button on a profile.", category: .connectionConnect, event: .trigger)

        guard canUseProfile else {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            Task {
                guard let url = await sessionService.getPlanSession(mode: .upgrade) else { return }

                @Dependency(\.linkOpener) var linkOpener
                linkOpener.open(url)
            }
            completion()
            return
        }

        log.debug("Will connect to profile: \(profile.logDescription)", category: .connectionConnect, event: .trigger)
        let spec = profile.connectionSpec(trigger: .profile)
        connectionCommandClient.send(.connect(spec, profile.connectionProtocol, .profile))
        completion()
    }

    func editAction() {
        editProfile?(profile)
    }

    func deleteAction() {
        coreAlertService.push(alert: WarningAlert(
            title: Localizable.deleteProfileHeader,
            message: Localizable.deleteProfileWarning,
            onConfirm: { [weak self] in
                guard let self else { return }
                profileManager.deleteProfile(profile)
            }
        ))
    }
}
