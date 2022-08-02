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

fileprivate let createProfileTitleId = "Profiles Overview"
fileprivate let createProfileButton = "Create Profile"
fileprivate let fastestButton = "Fastest"
fileprivate let randomButton = "Random"
fileprivate let editButton = "Edit"
fileprivate let deleteButton = "Delete"

class ManageProfilesRobot {
    
    func createProfile() -> CreateProfileRobot {
        app.buttons[createProfileButton].firstMatch.click()
        return CreateProfileRobot()
    }
    
    func editProfile() -> CreateProfileRobot {
        app.buttons[editButton].click()
        return CreateProfileRobot()
    }
    
    func deleteProfile() -> ManageProfilesRobot {
        app.buttons[deleteButton].click()
        return ManageProfilesRobot()
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkProfileOverViewIsOpen() -> ManageProfilesRobot {
            XCTAssertTrue(app.staticTexts[createProfileTitleId].exists)
            return ManageProfilesRobot()
        }
        
        @discardableResult
        func checkProfileIsCreated(_ name: String) -> ManageProfilesRobot {
            XCTAssert(app.tableRows.cells[name].waitForExistence(timeout: 2))
            return ManageProfilesRobot()
        }
    }
}
