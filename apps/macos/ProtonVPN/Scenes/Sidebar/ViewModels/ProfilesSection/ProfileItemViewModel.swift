//
//  ProfileItemViewModel.swift
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
import Domain
import LegacyCommon
import Strings
import VPNAppCore

class ProfileItemViewModel: AbstractProfileViewModel {
    private static let maxCharCount = 30

    @Dependency(\.upsellManager) private var upsellManager
    @Dependency(\.systemExtensionsCoordinator) private var systemExtensionsCoordinator
    @Dependency(\.connectionCommandClient) private var connectionCommandClient

    var enabled: Bool {
        !underMaintenance
    }

    var icon: ProfileIcon {
        profile.profileIcon
    }

    var name: NSAttributedString {
        var adjustedName = profile.name
        if adjustedName.count > ProfileItemViewModel.maxCharCount {
            adjustedName = adjustedName[0 ..< ProfileItemViewModel.maxCharCount] + "..."
        }
        return adjustedName.styled(font: .themeFont(.heading4), alignment: .left, lineBreakMode: .byTruncatingTail)
    }

    var hideDescription: Bool {
        !underMaintenance
    }

    var secondaryDescription: NSAttributedString {
        formSecondaryDescription()
    }

    func connectAction() {
        log.debug("Connect requested by selecting a profile.", category: .connectionConnect, event: .trigger)

        guard canUseProfile else {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            upsellManager.present(.countries)
            return
        }

        let performConnection = { [weak self] in
            guard let self else {
                return
            }

            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            log.debug("Will connect to profile: \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            let spec = profile.connectionSpec(trigger: .profile)
            connectionCommandClient.send(.connect(spec, profile.connectionProtocol, .profile))
        }

        guard profile.connectionProtocol.requiresSystemExtension else {
            performConnection()
            return
        }

        Task { @MainActor in
            let outcome = await systemExtensionsCoordinator.installOrUpdate(
                origin: .profileConnection,
                shouldStartTour: true,
                includedTypes: [.proTUN]
            )
            let result = outcome.accumulated
            switch result {
            case .success:
                performConnection()
            case let .failure(error):
                log.error("Error installing sysex when profile was selected: \(String(describing: error))")
            }
        }
    }

    private func formSecondaryDescription() -> NSAttributedString {
        let description: String = if underMaintenance {
            Localizable.maintenance
        } else {
            ""
        }
        return description.styled(.weak, font: .themeFont(bold: true), alignment: .right)
    }
}
