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

let app = XCUIApplication()

fileprivate let createProfileTitleId = "Profiles Overview"
fileprivate let createProfileTab = "Create Profile"
fileprivate let profileNameTextField = "Name"
fileprivate let featureStandart = "Standard"
fileprivate let featureSC = "Secure Core"
fileprivate let featureP2P = "P2P"
fileprivate let featureTor = "TOR"
fileprivate let countryField = "Select Country"
fileprivate let serverField = "Select Server"
fileprivate let vpnProtocolIkev2 = "IKEv2"
fileprivate let vpnProtocolOpenvpnUdp = "OpenVPN (UDP)"
fileprivate let vpnProtocolOpenvpnTcp = "OpenVPN (TCP)"
fileprivate let vpnProtocolWg = "Wireguard"
fileprivate let continueButton = "Continue"
fileprivate let cancelButton = "Cancel"
fileprivate let saveButton = "Save"
fileprivate let errorMessageSameName = "Profile with same name already exists"
fileprivate let errorMessageEmptyProfile = "Please enter a name, Please select a country, Please select a server"
fileprivate let errorMessageEnterName = "Please enter a name"
fileprivate let errorMessageSelectServerAndCountry = "Please select a country, Please select a server"
fileprivate let errorMessageSelectCountry = "Please select a country"
fileprivate let errorMessageSelectServer = "Please select a server"
fileprivate let errorMessageMaxNameLenght = "Maximum profile name length is 25 characters"
fileprivate let cancelProfileModalTtitle = "Create Profile"
fileprivate let cancelProfileDescribtion = "By continuing, current selection will be lost. Do you want to continue?"

class CreateProfileRobot {
    
    func setProfileDetails(_ name: String, _ countryname: String) -> CreateProfileRobot {
        return profileName(name)
            .selectCountry()
            .chooseCountry(countryname)
            .selectServer()
            .chooseServer()
    }
        
    func enterProfileName( _ name: String) -> CreateProfileRobot {
        return profileName(name)
    }
        
    func deleteProfileName() -> CreateProfileRobot {
        return deleteName()
    }

    func enterProfileCountry( _ countryname: String) -> CreateProfileRobot {
        return selectCountry()
            .chooseCountry(countryname)
    }
        
    func enterProfileServer() -> CreateProfileRobot {
        return selectServer()
            .chooseServer()
    }
        
    func saveProfile() -> CreateProfileRobot {
        app.buttons[saveButton].click()
        return CreateProfileRobot()
    }
        
    func saveProfileSuccessfully() -> ManageProfilesRobot {
        app.buttons[saveButton].click()
        return ManageProfilesRobot()
    }
        
    func cancelProfile() -> CreateProfileRobot {
        app.buttons[cancelButton].click()
        return CreateProfileRobot()
    }
        
    func cancelProfileModal() -> CreateProfileRobot {
        app.buttons[cancelButton].firstMatch.click()
        return CreateProfileRobot()
    }
        
    func continueProfileModal() -> ManageProfilesRobot {
        app.buttons[continueButton].click()
        return ManageProfilesRobot()
    }

    private func selectFeature() -> CreateProfileRobot {
        app.popUpButtons[featureStandart].click()
        return CreateProfileRobot()
    }
        
    private func chooseFeature() -> CreateProfileRobot {
        app.menuItems[featureTor].click()
        return CreateProfileRobot()
    }
        
    private func profileName(_ name: String) -> CreateProfileRobot {
        app.textFields[profileNameTextField].click()
        app.textFields[profileNameTextField].typeText(name)
        return self
    }
        
    private func deleteName() -> CreateProfileRobot {
        app.textFields[profileNameTextField].clearAndEnterText(text: "")
        return self
    }
        
    private func selectCountry() -> CreateProfileRobot {
        app.popUpButtons[countryField].click()
        return self
    }
        
    private func chooseCountry(_ countryname: String) -> CreateProfileRobot {
        app.menuItems[countryname].click()
        return self
    }
        
    private func selectServer() -> CreateProfileRobot {
        app.popUpButtons[serverField].click()
        return self
    }
        
    private func chooseServer() -> CreateProfileRobot {
        app.menuItems["￼  Fastest"].click()
        return self
    }
        
    private func selectProtocol(_ oldProtocol: String) -> CreateProfileRobot {
        app.popUpButtons[oldProtocol].click()
        return self
    }
    
    private func chooseProtocol(_ newProtocol: String) -> CreateProfileRobot {
        app.popUpButtons[newProtocol].click()
        return self
    }
        
    private func saveProfileClick() -> CreateProfileRobot {
        app.buttons[saveButton].click()
        return self
    }
        
    let verify = Verify()

    class Verify {
            
        @discardableResult
        func checkButtonExists() -> CreateProfileRobot {
            XCTAssertTrue(app.buttons[cancelButton].exists)
            XCTAssertTrue(app.buttons[saveButton].exists)
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageEmptyProfileExists() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[errorMessageEmptyProfile].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSameNameExists() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[errorMessageSameName].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageEnterName() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[errorMessageEnterName].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSelectServerAndCountry() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[errorMessageSelectServerAndCountry].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSelectCountry() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[errorMessageSelectCountry].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSelectServer() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[errorMessageSelectServer].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkModalIsOpen() -> CreateProfileRobot {
            XCTAssert(app.staticTexts[cancelProfileModalTtitle].waitForExistence(timeout: 1))
            XCTAssert(app.staticTexts[cancelProfileDescribtion].waitForExistence(timeout: 1))
            return CreateProfileRobot()
        }
    }
}
