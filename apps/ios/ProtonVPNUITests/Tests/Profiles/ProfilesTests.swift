//
//  ProfilesTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest
import fusion
import ProtonCoreTestingToolkitUITestsLogin
import UITestsHelpers

class ProfilesTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    private let profileRobot = ProfileRobot()
    private let createProfileRobot = CreateProfileRobot()
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testCreateAndDeleteProfile() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profileName + " ", countryName) // Only CI issue: the last letter is deleted
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .deleteProfile(profileName, countryName)
            .verify.profileIsDeleted(profileName, countryName)
    }
    
    func testCreateProfileWithTheSameName() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profileName, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .addNewProfile()
            .setProfileWithSameName(profileName, countryName)
            .saveProfile(robot: CreateProfileRobot.self)
            .verify.profileWithSameName()
    }
    
    func testEditProfile() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let countryName = "Belgium"
        let newCountryName = "Australia"
        
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profileName, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .editProfile(profileName)
            .editProfileDetails(profileName, countryName, newCountryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsEdited()
    }

    func testMakeDefaultAndSecureCoreProfilePlusUser() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        let serverVia = "Iceland"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .makeDefaultProfileWithSecureCore(profileName, countryName, serverVia)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
    }

    func testFreeUserCannotCreateProfile() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)

        loginRobot
            .enterCredentials(UserType.Free.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .verify.isShowingUpsellModal(ofType: .profiles)
    }
    
    func testRecommendedProfiles() {
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .verify.recommendedProfilesAreVisible()
    }
}
