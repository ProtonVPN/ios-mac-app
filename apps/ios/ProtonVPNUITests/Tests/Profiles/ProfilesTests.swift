//
//  ProfilesTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest

class ProfilesTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let profileRobot = ProfileRobot()
    private let createProfileRobot = CreateProfileRobot()
    
    override func setUp() {
        super.setUp()
    }

    func testCreateAndDeleteProfile() {
        let profileName = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        
        logInToProdIfNeeded()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profileName, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .deleteProfile(profileName, countryName)
            .verify.profileIsDeleted(profileName, countryName)
    }
    
    func testCreateProfileWithTheSameName() {
        let profileName = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        
        logInToProdIfNeeded()
        mainRobot
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
        let profileName = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Belgium"
        let newCountryName = "Australia"
        
        logInToProdIfNeeded()
        mainRobot
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
    
    func testFreeUserCannotCreateProfileWithSecureCore() {
        let profileName = StringUtils().randomAlphanumericString(length: 10)
    
        logoutIfNeeded()
        changeEnvToProdIfNedded()
        openLoginScreen()
        loginAsFreeUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setSecureCoreProfile(profileName)
            .verify.upsellMessage()
    }
    
    func testBasicUserCannotCreateProfileWithSecureCore() {
        let profileName = StringUtils().randomAlphanumericString(length: 10)
    
        logoutIfNeeded()
        changeEnvToProdIfNedded()
        openLoginScreen()
        loginAsBasicUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setSecureCoreProfile(profileName)
            .verify.upsellMessage()
    }
    
    func testMakeDefaultAndSecureCoreProfilePlusUser() {
        let profileName = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        let serverVia = "Iceland"
        
        logoutIfNeeded()
        changeEnvToProdIfNedded()
        openLoginScreen()
        loginAsPlusUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .makeDefaultProfileWithSecureCore(profileName, countryName, serverVia)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
    }
    
    func testRecommendedProfiles() {
        
        logInToProdIfNeeded()
        mainRobot
            .goToProfilesTab()
            .verify.recommendedProfilesAreVisible()
    }
}
