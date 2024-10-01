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

fileprivate let createProfileTitleId = "Profiles Overview"
fileprivate let createProfileTab = "CreateNewProfileButton"
fileprivate let profileNameTextField = "NameTextField"
fileprivate let featureStandard = "Standard"
fileprivate let featureSC = "Secure Core"
fileprivate let featureP2P = "P2P"
fileprivate let featureTor = "TOR"
fileprivate let countryField = "CountryList"
fileprivate let serverField = "ServerList"
fileprivate let vpnProtocolIkev2 = "IKEv2"
fileprivate let vpnProtocolOpenvpnUdp = "OpenVPN (UDP)"
fileprivate let vpnProtocolOpenvpnTcp = "OpenVPN (TCP)"
fileprivate let vpnProtocolWg = "Wireguard"
fileprivate let continueButton = "Continue"
fileprivate let cancelButton = "CancelButton"
fileprivate let saveButton = "SaveButton"
fileprivate let errorMessageSameName = "Profile with same name already exists"
fileprivate let errorMessageEmptyProfile = "Please enter a name, Please select a country, Please select a server"
fileprivate let errorMessageEnterName = "Please enter a name"
fileprivate let errorMessageSelectServerAndCountry = "Please select a country, Please select a server"
fileprivate let errorMessageSelectCountry = "Please select a country"
fileprivate let errorMessageSelectServer = "Please select a server"
fileprivate let errorMessageMaxNameLength = "Maximum profile name length is 25 characters"
fileprivate let errorMessage = "ErrorMessage"
fileprivate let cancelProfileModalTitle = "Create Profile"
fileprivate let cancelProfileDescription = "By continuing, current selection will be lost. Do you want to continue?"

class CreateProfileRobot: CoreElements {
    
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
        button(saveButton).tap()
        return CreateProfileRobot()
    }
        
    func saveProfileSuccessfully() -> ManageProfilesRobot {
        button(saveButton).tap()
        return ManageProfilesRobot()
    }
        
    func cancelProfile() -> CreateProfileRobot {
        button(cancelButton).tap()
        return CreateProfileRobot()
    }
        
    func cancelProfileModal() -> CreateProfileRobot {
        button(cancelButton).firstMatch().tap()
        return CreateProfileRobot()
    }
        
    func continueProfileModal() -> ManageProfilesRobot {
        button(continueButton).firstMatch().tap()
        return ManageProfilesRobot()
    }

    private func selectFeature() -> CreateProfileRobot {
        button(featureStandard).firstMatch().tap()
        return CreateProfileRobot()
    }
        
    private func chooseFeature() -> CreateProfileRobot {
        button(featureTor).tap()
        return CreateProfileRobot()
    }
        
    private func profileName(_ name: String) -> CreateProfileRobot {
        textField(profileNameTextField).tap()
        textField(profileNameTextField).typeText(name)
        return self
    }
        
    private func deleteName() -> CreateProfileRobot {
        textField(profileNameTextField).clearText().typeText("")
        return self
    }
        
    private func selectCountry() -> CreateProfileRobot {
        popUpButton(countryField).tap()
        return self
    }
        
    private func chooseCountry(_ countryname: String) -> CreateProfileRobot {
        menuItem("￼  \(countryname)").tap()
        return self
    }
        
    private func selectServer() -> CreateProfileRobot {
        popUpButton(serverField).tap()
        return self
    }
        
    private func chooseServer() -> CreateProfileRobot {
        menuItem("￼  Fastest").tap()
        return self
    }
        
    private func selectProtocol(_ oldProtocol: String) -> CreateProfileRobot {
        popUpButton(oldProtocol).tap()
        return self
    }
    
    private func chooseProtocol(_ newProtocol: String) -> CreateProfileRobot {
        popUpButton(newProtocol).tap()
        return self
    }
        
    private func saveProfileClick() -> CreateProfileRobot {
        button(saveButton).tap()
        return self
    }
        
    let verify = Verify()

    class Verify: CoreElements {
            
        @discardableResult
        func checkCreateProfileViewIsOpened() -> CreateProfileRobot {
            button(cancelButton).checkExists()
            button(saveButton).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageEmptyProfileExists() -> CreateProfileRobot {
            staticText(errorMessageEmptyProfile).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSameNameExists() -> CreateProfileRobot {
            staticText(errorMessageSameName).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageEnterName() -> CreateProfileRobot {
            staticText(errorMessageEnterName).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSelectServerAndCountry() -> CreateProfileRobot {
            staticText(errorMessageSelectServerAndCountry).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSelectCountry() -> CreateProfileRobot {
            staticText(errorMessageSelectCountry).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkErrorMessageSelectServer() -> CreateProfileRobot {
            staticText(errorMessageSelectServer).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
            
        @discardableResult
        func checkModalIsOpen() -> CreateProfileRobot {
            staticText(cancelProfileModalTitle).waitUntilExists(time: 1).checkExists()
            staticText(cancelProfileDescription).waitUntilExists(time: 1).checkExists()
            return CreateProfileRobot()
        }
    }
}
