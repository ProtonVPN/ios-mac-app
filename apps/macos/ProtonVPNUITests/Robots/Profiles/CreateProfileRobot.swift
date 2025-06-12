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

private let createProfileTitleId = "Profiles Overview"
private let createProfileTab = "CreateNewProfileButton"
private let profileNameTextField = "NameTextField"
private let featureStandard = "Standard"
private let featureSC = "Secure Core"
private let featureP2P = "P2P"
private let featureTor = "TOR"
private let countryField = "CountryList"
private let serverField = "ServerList"
private let vpnProtocolIkev2 = "IKEv2"
private let vpnProtocolOpenvpnUdp = "OpenVPN (UDP)"
private let vpnProtocolOpenvpnTcp = "OpenVPN (TCP)"
private let vpnProtocolWg = "Wireguard"
private let continueButton = "Continue"
private let cancelButton = "CancelButton"
private let saveButton = "SaveButton"
private let errorMessageSameName = "Profile with same name already exists"
private let errorMessageEmptyProfile = "Please enter a name, Please select a country, Please select a server"
private let errorMessageEnterName = "Please enter a name"
private let errorMessageSelectServerAndCountry = "Please select a country, Please select a server"
private let errorMessageSelectCountry = "Please select a country"
private let errorMessageSelectServer = "Please select a server"
private let errorMessageMaxNameLength = "Maximum profile name length is 25 characters"
private let errorMessage = "ErrorMessage"
private let cancelProfileModalTitle = "Create Profile"
private let cancelProfileDescription = "By continuing, current selection will be lost. Do you want to continue?"

class CreateProfileRobot: CoreElements {
    func setProfileDetails(_ name: String, _ countryname: String) -> CreateProfileRobot {
        profileName(name)
            .selectCountry()
            .chooseCountry(countryname)
            .selectServer()
            .chooseServer()
    }
        
    func enterProfileName( _ name: String) -> CreateProfileRobot {
        profileName(name)
    }
        
    func deleteProfileName() -> CreateProfileRobot {
        deleteName()
    }

    func enterProfileCountry( _ countryname: String) -> CreateProfileRobot {
        selectCountry()
            .chooseCountry(countryname)
    }
        
    func enterProfileServer() -> CreateProfileRobot {
        selectServer()
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
