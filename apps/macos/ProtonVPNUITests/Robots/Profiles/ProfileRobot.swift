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

fileprivate let profilesButton = "Profiles"
fileprivate let fastestButton = "Fastest"
fileprivate let randomButton = "Random"
fileprivate let createProfileButton = "Create Profile"
fileprivate let manageProfileButton = "Manage Profiles"

class ProfileRobot {
    
    @discardableResult
    func createProfile() -> CreateProfileRobot {
        app.buttons[createProfileButton].click()
        return CreateProfileRobot()
    }
     
    func manageProfiles() -> ManageProfilesRobot {
        app.buttons[manageProfileButton].click()
        return ManageProfilesRobot()
    }
     
    let verify = Verify()

    class Verify {
         
        @discardableResult
        func checkDefaultProfilesExist() -> ProfileRobot {
            XCTAssert(app.tableRows.cells[fastestButton].waitForExistence(timeout: 3))
            XCTAssert(app.tableRows.cells[randomButton].waitForExistence(timeout: 3))
            return ProfileRobot()
        }
         
        func checkButtonsExist() -> ProfileRobot {
            XCTAssertTrue(app.buttons[profilesButton].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[profilesButton].isEnabled)
            return ProfileRobot()
        }
    }
}
