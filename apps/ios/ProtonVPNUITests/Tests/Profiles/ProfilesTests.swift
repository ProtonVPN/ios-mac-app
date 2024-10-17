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
    
    @MainActor
    func testCreateAndDeleteProfile() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let randomCountry = try await ServersListUtils.getRandomCountry()
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profileName, randomCountry.name)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .deleteProfile(profileName, randomCountry.name)
            .verify.profileIsDeleted(profileName, randomCountry.name)
    }
    
    @MainActor
    func testCreateProfileWithTheSameName() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        
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
    
    @MainActor
    func testEditProfile() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        let (newCountryName, _) = try await ServersListUtils.getRandomCountry()
        
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
    
    @MainActor
    func testMakeDefaultAndSecureCoreProfilePlusUser() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        
        let randomSecureCoreCountry = try await ServersListUtils.getRandomCountry(secureCore: true)
        let serverVia = try await ServersListUtils.getEntryCountries(for: randomSecureCoreCountry.code).first ?? ""
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .makeDefaultProfileWithSecureCore(profileName, randomSecureCoreCountry.name, serverVia)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
    }
    
    @MainActor
    func testFreeUserCannotCreateProfile() {
        
        loginRobot
            .enterCredentials(UserType.Free.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .addNewProfile()
            .verify.isShowingUpsellModal(ofType: .profiles)
    }
    
    @MainActor
    func testRecommendedProfiles() {
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .verify.recommendedProfilesAreVisible()
    }
}
