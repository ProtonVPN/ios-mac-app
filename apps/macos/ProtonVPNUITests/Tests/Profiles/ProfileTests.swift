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

class ProfileTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    private let mainRobot = MainRobot()
    private let profilesRobot = ProfileRobot()
    private let createProfileRobot = CreateProfileRobot()
    private let manageProfilesRobot = ManageProfilesRobot()
    
    override func setUp() {
        super.setUp()
    }
    
    func testCreateEmptyProfile() {
        
        let name = StringUtils().randomAlphanumericString(length: 8)
        let country = "￼  Austria"
        
        logInIfNeeded()
        mainRobot
            .openProfiles()
            .verify.checkProfileOverViewIsOpen()
            .createProfile()
            .verify.checkButtonExists()
            .saveProfile()
            .verify.checkErrorMessageEmptyProfileExists()
            .enterProfileName(name)
            .saveProfile()
            .verify.checkErrorMessageSelectServerAndCountry()
            .enterProfileCountry(country)
            .saveProfile()
            .verify.checkErrorMessageSelectServer()
            .enterProfileServer()
            .deleteProfileName()
            .saveProfile()
            .verify.checkErrorMessageEnterName()
    }
    
    func testCancelProfile() {
        
        let country = "￼  Austria"

        logInIfNeeded()
        mainRobot
            .openProfiles()
            .verify.checkProfileOverViewIsOpen()
            .createProfile()
            .verify.checkButtonExists()
            .enterProfileCountry(country)
            .cancelProfile()
            .verify.checkModalIsOpen()
            .continueProfileModal()
            .verify.checkProfileOverViewIsOpen()
    }
    
    func testCreateProfileWithTheSameName() {
        
        let name = StringUtils().randomAlphanumericString(length: 8)
        let country = "￼  Austria"

        logInIfNeeded()
        mainRobot
            .openProfiles()
            .verify.checkProfileOverViewIsOpen()
            .createProfile()
            .verify.checkButtonExists()
            .setProfileDetails(name, country)
            .saveProfileSuccessfully()
            .createProfile()
            .verify.checkButtonExists()
            .setProfileDetails(name, country)
            .saveProfile()
            .verify.checkErrorMessageSameNameExists()
    }
    
    func testNewProfileAppearsInTheSettings() {
        
        let name = StringUtils().randomAlphanumericString(length: 8)
        let country = "￼  Austria"
        let autoConnectDisabled = "￼  Disabled"
        let qcFastest = "￼  Fastest"

        logInIfNeeded()
        mainRobot
            .openProfiles()
            .verify.checkProfileOverViewIsOpen()
            .createProfile()
            .verify.checkButtonExists()
            .setProfileDetails(name, country)
            .saveProfileSuccessfully()
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .selectQuickConnect(qcFastest)
            .verify.checkProfileIsCreated("￼  " + name)
            .selectAutoConnect(autoConnectDisabled)
            .verify.checkProfileIsCreated("￼  " + name)
    }
    
    func testQuickConnectToAServerViaUnavailableProfile() {
        
        let name = StringUtils().randomAlphanumericString(length: 8)
        let country = "￼  Austria (Upgrade Required)"
        let qcFastest = "￼  Fastest"
        
        logoutIfNeeded()
        loginAsFreeUser()
        mainRobot
            .openProfiles()
            .verify.checkProfileOverViewIsOpen()
            .createProfile()
            .verify.checkButtonExists()
            .setProfileDetails(name, country)
            .saveProfileSuccessfully()
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .selectQuickConnect(qcFastest)
            .verify.checkProfileIsCreated("￼  " + name)
            .selectProfile("￼  " + name)
            .closeSettings()
            .closeProfilesOverview()
            .quickConnectToAServer()
            .verify.checkUpsellModalIsOpen()
    }
}
