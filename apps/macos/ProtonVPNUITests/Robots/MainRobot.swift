//
//  Created on 2022-01-11.
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

fileprivate let qcButton = "Quick Connect"
fileprivate let preferencesTitle = "Preferences"
fileprivate let menuItemReportAnIssue = "Report an Issue..."
fileprivate let menuItemProfiles = "Overview"
fileprivate let statusTitle = "You are not connected"

class MainRobot {

    func openProfiles() -> ManageProfilesRobot {
        app.tabGroups["Profiles"].forceClick()
        app.buttons["Create Profile"].click()
        return ManageProfilesRobot()
    }
    
    func closeProfilesOverview() -> MainRobot {
        let preferencesWindow = app.windows["Profiles Overview"]
        preferencesWindow.buttons[XCUIIdentifierCloseWindow].click()
        return MainRobot()
    }
    
    func openAppSettings() -> SettingsRobot {
        window.typeKey(",", modifierFlags: [.command]) // Settings…
        return SettingsRobot()
    }
    
    func quickConnectToAServer() -> SettingsRobot {
        app.buttons[qcButton].forceClick()
        return SettingsRobot()
    }

    func logOut() -> LoginRobot {
            let logoutButton = app.menuBars.menuItems["Sign out"]
            logoutButton.click()
            return LoginRobot()
        }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkSettingsModalIsClosed() -> SettingsRobot {
            XCTAssertFalse(app.buttons[preferencesTitle].exists)
            XCTAssertTrue(app.buttons[qcButton].exists)
            return SettingsRobot()
        }
        
        @discardableResult
        func checkUserIsLoggedIn() -> SettingsRobot {
            XCTAssert(app.staticTexts[statusTitle].waitForExistence(timeout: 10))
            XCTAssert(app.buttons[qcButton].waitForExistence(timeout: 10))
            return SettingsRobot()
        }
    }
}
