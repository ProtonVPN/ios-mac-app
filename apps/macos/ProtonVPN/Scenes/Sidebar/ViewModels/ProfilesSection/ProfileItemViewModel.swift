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
import LegacyCommon
import Modals_macOS
import Strings

class ProfileItemViewModel: AbstractProfileViewModel {
    
    private static let maxCharCount = 30
    
    private let vpnGateway: VpnGatewayProtocol
    private let alertService: CoreAlertService
    private let sysexManager: SystemExtensionManager
    
    var enabled: Bool {
        return !underMaintenance
    }
    
    var icon: ProfileIcon {
        return profile.profileIcon
    }
    
    var name: NSAttributedString {
        var adjustedName = profile.name
        if adjustedName.count > ProfileItemViewModel.maxCharCount {
            adjustedName = adjustedName[0..<ProfileItemViewModel.maxCharCount] + "..."
        }
        return adjustedName.styled(font: .themeFont(.heading4), alignment: .left, lineBreakMode: .byTruncatingTail)
    }
    
    var hideDescription: Bool {
        return !underMaintenance
    }
    
    var secondaryDescription: NSAttributedString {
        return formSecondaryDescription()
    }
    
    init(profile: Profile,
         vpnGateway: VpnGatewayProtocol,
         alertService: CoreAlertService,
         sysexManager: SystemExtensionManager) {
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.sysexManager = sysexManager
        super.init(profile: profile)
    }
    
    func connectAction() {
        log.debug("Connect requested by selecting a profile.", category: .connectionConnect, event: .trigger)
        
        guard canUseProfile else {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            alertService.push(alert: AllCountriesUpsellAlert())
            return
        }

        let performConnection = { [weak self] in
            guard let self = self else {
                return
            }

            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Will connect to profile: \(self.profile.logDescription)", category: .connectionConnect, event: .trigger)
            self.vpnGateway.connectTo(profile: self.profile)
        }

        guard profile.connectionProtocol.requiresSystemExtension else {
            performConnection()
            return
        }

        sysexManager.installOrUpdateExtensionsIfNeeded(shouldStartTour: true) { result in
            switch result {
            case .success:
                performConnection()
            case let .failure(error):
                log.error("Error installing sysex when profile was selected: \(String(describing: error))")
            }
        }
    }
    
    private func formSecondaryDescription() -> NSAttributedString {
        let description: String = underMaintenance ? Localizable.maintenance : ""
        return description.styled(.weak, font: .themeFont(bold: true), alignment: .right)
    }
}
