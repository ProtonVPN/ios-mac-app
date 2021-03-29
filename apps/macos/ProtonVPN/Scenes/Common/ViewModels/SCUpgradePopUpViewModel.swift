//
//  SCUpgradePopUpViewModel.swift
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

import Foundation
import vpncore

class SCUpgradePopUpViewModel {
    
    let buttonPressed: (() -> Void)?
    
    init(buttonPressed: (() -> Void)?) {
        self.buttonPressed = buttonPressed
    }
    
    func learnMoreAction() {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.learnMore)
    }
    
    func cancelAction() {
        buttonPressed?()
    }
    
    func upgradeAction() {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.upgrade)
        buttonPressed?()
    }
}
