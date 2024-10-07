//
//  Created on 2022-02-15.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import XCTest
import fusion

fileprivate let secureCoreButton = "SecureCoreButton"
fileprivate let netShieldButton = "NetShieldButton"
fileprivate let killSwitchButton = "KillSwitchButton"
fileprivate let qsTitle = "QSTitle"
fileprivate let qsDescription = "QSDescription"
fileprivate let learnMoreButton = "LearnMoreButton"
fileprivate let qsNote = "QSNote"
fileprivate let upgradeButton = "UpgradeButton"
fileprivate let killSwitchModalTitle = "Turn Kill Switch on?"
fileprivate let notNowButton = "Not now"
fileprivate let continueButton = "Continue"
fileprivate let modalUpgradeButton = "ModalUpgradeButton"
fileprivate let modalTitle = "TitleLabel"
fileprivate let modalDescription = "DescriptionLabel"

class QuickSettingsRobot: CoreElements {
    
    func secureCoreDropdown() -> QuickSettingsRobot {
        button(secureCoreButton).tapInCenter()
        return QuickSettingsRobot()
    }
    
    func netShieldDropdown() -> QuickSettingsRobot {
        button(netShieldButton).tapInCenter()
        return QuickSettingsRobot()
    }
    
    func killSwitchDropdown() -> QuickSettingsRobot {
        button(killSwitchButton).tapInCenter()
        return QuickSettingsRobot()
    }
    
    func continueEnable() -> QuickSettingsRobot {
        button(continueButton).forceTap()
        return QuickSettingsRobot()
    }
    
    func enableNotNow() -> QuickSettingsRobot {
        button(notNowButton).forceTap()
        return QuickSettingsRobot()
    }
    
    func upgradeFeature() -> QuickSettingsRobot {
        button(upgradeButton).forceTap()
        return QuickSettingsRobot()
    }
    
    func closeUpsellModal() -> QuickSettingsRobot {
        dialog().firstMatch().onChild(button("_XCUI:CloseWindow")).tap()
        return QuickSettingsRobot()
    }
    
    let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func checkDropdownIsOpen() -> QuickSettingsRobot {
            staticText(qsTitle).checkExists()
            staticText(qsDescription).checkExists()
            button(learnMoreButton).checkExists()
            staticText(qsNote).checkExists()
            return QuickSettingsRobot()
        }
        
        @discardableResult
        func checkUpgradeRequired() -> QuickSettingsRobot {
            button(upgradeButton).checkExists()
            return QuickSettingsRobot()
        }
        
        @discardableResult
        func checkModalIsOpen() -> QuickSettingsRobot {
            staticText("By activating Kill Switch, you won't be able to access devices on your local network. ").checkExists()
            button(notNowButton).checkExists()
            button(continueButton).checkExists()
            return QuickSettingsRobot()
        }
        
        @discardableResult
        func checkUpsellModalIsOpen() -> QuickSettingsRobot {
            staticText(modalTitle).checkExists()
            staticText(modalDescription).checkExists()
            button(modalUpgradeButton).checkEnabled()
            return QuickSettingsRobot()
        }
    }
}
