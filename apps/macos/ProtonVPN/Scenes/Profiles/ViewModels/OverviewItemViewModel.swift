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
import vpncore

protocol OverviewItemViewModelDelegate: class {
    
    func showDeleteWarning(_ viewModel: WarningPopupViewModel)
}

class OverviewItemViewModel: AbstractProfileViewModel {
    
    private let editProfile: ((Profile) -> Void)?
    private let profileManager: ProfileManager
    private let vpnGateway: VpnGatewayProtocol
    
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
    
    var connectButtonTitle: String {
        return formConnectButtonTitle()
    }
    
    init(profile: Profile, editProfile: ((Profile) -> Void)?, profileManager: ProfileManager, vpnGateway: VpnGatewayProtocol, userTier: Int) {
        self.editProfile = editProfile
        self.profileManager = profileManager
        self.vpnGateway = vpnGateway
        super.init(profile: profile, userTier: userTier)
    }
    
    func connectAction(completion: () -> Void) {
        guard !isUsersTierTooLow else {
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
            completion()
            return
        }
        
        vpnGateway.connectTo(profile: profile)
        completion()
    }
    
    func editAction() {
        editProfile?(profile)
    }
    
    func deleteAction() {
        guard let delegate = delegate else { return }
        
        let warningViewModel = WarningPopupViewModel(image: #imageLiteral(resourceName: "temp"), title: LocalizedString.deleteProfileHeader,
                                              description: LocalizedString.deleteProfileWarning) { [weak self] in
                                                guard let `self` = self else { return }
                                                self.profileManager.deleteProfile(self.profile)
        }
        delegate.showDeleteWarning(warningViewModel)
    }
    
    private func formConnectButtonTitle() -> String {
        if underMaintenance {
            return LocalizedString.maintenance
        } else {
            return LocalizedString.connect
        }
    }
}
