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

    func testCreateAndDeleteProfileFreeUser() {
        let profilename = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        
        loginAsFreeUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profilename, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.createdProfile()
            .deleteProfile(profilename, countryName)
            .verify.profileIsDeleted(profilename, countryName)
    }
    
    func testCreateProfileWithTheSameNameBasicUser() {
        let profilename = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
    
        loginAsBasicUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profilename, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.createdProfile()
            .addNewProfile()
            .setProfileWithSameName(profilename, countryName)
            .saveProfile(robot: CreateProfileRobot.self)
            .verify.profileWithSameName()
    }
    
    func testFreeUserCannotCreateProfileWithSecureCore() {
        let profilename = StringUtils().randomAlphanumericString(length: 10)
    
        loginAsFreeUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setSecureCoreProfile(profilename)
            .verify.subscribtionRequiredMessage()
    }
    
    func testBasicUserCannotCreateProfileWithSecureCore() {
        let profilename = StringUtils().randomAlphanumericString(length: 10)
    
        loginAsBasicUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setSecureCoreProfile(profilename)
            .verify.subscribtionRequiredMessage()
    }
    
    func testMakeDefaultAndSecureCoreProfilePlusUser() {
        let profilename = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Netherlands"
        let serverVia = "Iceland"
        
        loginAsPlusUser()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .makeDefaultProfileWithSecureCore(profilename, countryName, serverVia)
            .saveProfile(robot: ProfileRobot.self)
            .verify.createdProfile()
    }
}
