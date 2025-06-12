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
import fusion
import Strings

private let createProfileTitleId = "Profiles Overview"
private let createProfileButton = "Create Profile"
private let fastestButton = "Fastest"
private let randomButton = "Random"
private let editButton = "Edit"
private let deleteButton = "Delete"

class ManageProfilesRobot: CoreElements {
    func createProfile() -> CreateProfileRobot {
        button(createProfileButton).firstMatch().tap()
        return CreateProfileRobot()
    }
    
    func editProfile() -> CreateProfileRobot {
        button(editButton).firstMatch().tap()
        return CreateProfileRobot()
    }
    
    func deleteProfile() -> ManageProfilesRobot {
        button(deleteButton).firstMatch().tap()
        return ManageProfilesRobot()
    }
    
    let verify = Verify()
    
    class Verify: Verifier {
        @discardableResult
        func checkProfileOverViewIsOpen() -> ManageProfilesRobot {
            windows(Localizable.profilesOverview).checkExists()
            cell(Localizable.fastest).checkExists()
            return ManageProfilesRobot()
        }
        
        @discardableResult
        func checkProfileIsCreated(_ name: String) -> ManageProfilesRobot {
            cell(name).waitUntilExists(time: 2).checkExists()
            return ManageProfilesRobot()
        }
    }
}
