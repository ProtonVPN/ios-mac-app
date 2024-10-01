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

fileprivate let profilesButton = "Profiles"
fileprivate let fastestButton = "Fastest"
fileprivate let randomButton = "Random"
fileprivate let createProfileButton = "Create Profile"
fileprivate let manageProfileButton = "Manage Profiles"

class ProfileRobot: CoreElements {
    
    @discardableResult
    func createProfile() -> CreateProfileRobot {
        button(createProfileButton).tap()
        return CreateProfileRobot()
    }
     
    func manageProfiles() -> ManageProfilesRobot {
        button(manageProfileButton).tap()
        return ManageProfilesRobot()
    }
     
    let verify = Verify()

    class Verify: CoreElements {
         
        @discardableResult
        func checkDefaultProfilesExist() -> ProfileRobot {
            table().onChild(cell(fastestButton)).waitUntilExists().checkExists()
            table().onChild(cell(randomButton)).waitUntilExists().checkExists()
            return ProfileRobot()
        }
         
        func checkButtonsExist() -> ProfileRobot {
            button(profilesButton).waitUntilExists(time: 5).checkExists()
            button(profilesButton).checkEnabled()
            return ProfileRobot()
        }
    }
}
