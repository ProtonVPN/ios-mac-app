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
import vpncore

class ProfileItemViewModel: AbstractProfileViewModel {
    
    private static let maxCharCount = 30
    
    private let vpnGateway: VpnGatewayProtocol
    
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
        return adjustedName.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left, lineBreakMode: .byTruncatingTail)
    }
    
    var hideDescription: Bool {
        return !underMaintenance
    }
    
    var secondaryDescription: NSAttributedString {
        return formSecondaryDescription()
    }
    
    init(profile: Profile, vpnGateway: VpnGatewayProtocol, userTier: Int) {
        self.vpnGateway = vpnGateway
        super.init(profile: profile, userTier: userTier)
    }
    
    func connectAction() {
        guard !isUsersTierTooLow else {
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
            return
        }
        vpnGateway.connectTo(profile: profile)
    }
    
    private func formSecondaryDescription() -> NSAttributedString {
        let description: String
        if underMaintenance {
            description = LocalizedString.maintenance
        } else {
            description = ""
        }
        return description.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .right)
    }
}
