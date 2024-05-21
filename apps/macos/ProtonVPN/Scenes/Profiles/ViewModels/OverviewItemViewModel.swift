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
import LegacyCommon
import Strings

protocol OverviewItemViewModelDelegate: AnyObject {
    func showDeleteWarning(_ viewModel: WarningPopupViewModel)
}

final class OverviewItemViewModel: AbstractProfileViewModel {
    
    private let editProfile: ((Profile) -> Void)?
    private let profileManager: ProfileManager
    private let vpnGateway: VpnGatewayProtocol
    private let sessionService: SessionService
    
    weak var delegate: OverviewItemViewModelDelegate?
    
    var canConnect: Bool {
        return !underMaintenance
    }
    
    var icon: ProfileIcon {
        return profile.profileIcon
    }
    
    var name: NSAttributedString {
        return attributedName(forProfile: profile)
    }
    
    var description: NSAttributedString {
        return attributedDescription(forProfile: profile)
    }
    
    var isSystemProfile: Bool {
        return profile.profileType == .system
    }

    init(profile: Profile, editProfile: ((Profile) -> Void)?, profileManager: ProfileManager, vpnGateway: VpnGatewayProtocol, sessionService: SessionService) {
        self.editProfile = editProfile
        self.profileManager = profileManager
        self.vpnGateway = vpnGateway
        self.sessionService = sessionService
        super.init(profile: profile)
    }
    
    func connectAction(completion: () -> Void) {
        log.debug("Connect requested by pressing Connect button on a profile.", category: .connectionConnect, event: .trigger)
        
        guard canUseProfile else {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            Task {
                let url = await sessionService.getPlanSession(mode: .upgrade)
                SafariService.openLink(url: url)
            }
            completion()
            return
        }
        
        log.debug("Will connect to profile: \(profile.logDescription)", category: .connectionConnect, event: .trigger)
        vpnGateway.connectTo(profile: profile)
        completion()
    }
    
    func editAction() {
        editProfile?(profile)
    }
    
    func deleteAction() {
        guard let delegate = delegate else { return }
        
        let warningViewModel = WarningPopupViewModel(title: Localizable.deleteProfileHeader, description: Localizable.deleteProfileWarning) { [weak self] in
            guard let self = self else {
                return
            }

            self.profileManager.deleteProfile(self.profile)
        }
        delegate.showDeleteWarning(warningViewModel)
    }
}
