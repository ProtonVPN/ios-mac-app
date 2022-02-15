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

class QuickSettingsRobot {
    
    func secureCoreDropdown() -> QuickSettingsRobot {
        app.buttons[secureCoreButton].click()
        return QuickSettingsRobot()
    }
    
    func netShiedlDropdown() -> QuickSettingsRobot {
        app.buttons[netShieldButton].click()
        return QuickSettingsRobot()
    }
    
    func killSwitchDropdown() -> QuickSettingsRobot {
        app.buttons[killSwitchButton].click()
        return QuickSettingsRobot()
    }
    
    func continueEnable() -> QuickSettingsRobot {
        app.buttons[continueButton].click()
        return QuickSettingsRobot()
    }
    
    func enableNotNow() -> QuickSettingsRobot {
        app.buttons[notNowButton].click()
        return QuickSettingsRobot()
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkDropdownIsOpen() -> QuickSettingsRobot {
            XCTAssertTrue(app.staticTexts[qsTitle].exists)
            XCTAssertTrue(app.staticTexts[qsDescription].exists)
            XCTAssertTrue(app.buttons[learnMoreButton].exists)
            XCTAssertTrue(app.staticTexts[qsNote].exists)
            return QuickSettingsRobot()
        }
        
        @discardableResult
        func checkUpgradeRequired() -> QuickSettingsRobot {
            XCTAssertTrue(app.buttons[upgradeButton].exists)
            return QuickSettingsRobot()
        }
        
        @discardableResult
        func checkModalIsOpen() -> QuickSettingsRobot {
            XCTAssertTrue(app.staticTexts["By activating Kill Switch, you won't be able to access devices on your local network. "].exists)
            XCTAssertTrue(app.buttons[notNowButton].exists)
            XCTAssertTrue(app.buttons[continueButton].exists)
            return QuickSettingsRobot()
        }
    }
}
