//
//  ProfilesTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest

class ProfilesTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    private let profileRobot = ProfileRobot()
    private let createProfileRobot = CreateProfileRobot()
    
    override func setUp() {
        super.setUp()
    }

    func testCreateAndDeleteProfileFreeUser() {
        let profilename = StringUtils().randomAlphanumericString()
        let countryName = "Netherlands"
        
        loginAsFreeUser()
        profileRobot
            .addNewProfile()
            .setProfileDetails(profilename, countryName)
            .saveProf(robot: ProfileRobot.self)
            .verify.createdProfile()
            .deleteProfile(profilename, countryName)
            .verify.profileIsDeleted(profilename, countryName)
    }
    
    func testCreateProfileWithTheSameNameBasicUser() {
        let profilename = StringUtils().randomAlphanumericString()
        let countryName = "Netherlands"
    
        loginAsBasicUser()
        profileRobot
            .addNewProfile()
            .setProfileDetails(profilename, countryName)
            .saveProf(robot: ProfileRobot.self)
            .verify.createdProfile()
            .addNewProfile()
            .setProfileWithSameName(profilename, countryName)
            .saveProf(robot: CreateProfileRobot.self)
            .verify.profileWithSameName()
    }
}
