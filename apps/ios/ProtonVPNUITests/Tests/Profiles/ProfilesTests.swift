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
        homeRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    @MainActor
    func testCreateAndDeleteProfile() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let randomCountry = try await ServersListUtils.getRandomCountry()
        
        loginAndOpenProfiles(as: UserType.Basic.credentials)
            .tapAddNewProfile()
            .verify.isOnProfilesEditScreen()
            .setProfileDetails(profile: profileName, country: randomCountry.name)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .deleteProfile(profileName, randomCountry.name)
            .verify.profileIsDeleted(profileName)
    }
    
    @MainActor
    func testCreateProfileWithTheSameName() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        
        loginAndOpenProfiles(as: UserType.Plus.credentials)
            .tapAddNewProfile()
            .verify.isOnProfilesEditScreen()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .tapAddNewProfile()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: CreateProfileRobot.self)
            .verify.profileWithSameName()
    }
    
    @MainActor
    func testEditProfile() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let newProfileName = StringUtils.randomAlphanumericString(length: 10)
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        let (newCountryName, _) = try await ServersListUtils.getRandomCountry()
        
        loginAndOpenProfiles(as: UserType.Plus.credentials)
            .tapAddNewProfile()
            .verify.isOnProfilesEditScreen()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .editProfile(profileName)
            .setProfileDetails(profile: newProfileName, country: newCountryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsEdited(profile: newProfileName)
    }
    
    @MainActor
    func testMakeSecureCoreProfilePlusUser() async throws {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        
        let randomSecureCoreCountry = try await ServersListUtils.getRandomCountry(secureCore: true)
        let serverVia = try await ServersListUtils.getEntryCountries(for: randomSecureCoreCountry.code).first ?? ""
        
        loginAndOpenProfiles(as: UserType.Basic.credentials)
            .tapAddNewProfile()
            .verify.isOnProfilesEditScreen()
            .setProfileDetails(profile: profileName, country: randomSecureCoreCountry.name, server: serverVia, secureCoreState: true)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
    }
    
    @MainActor
    func testFreeUserCannotCreateProfile() {
        
        loginAndOpenProfiles(as: UserType.Free.credentials)
            .tapAddNewProfile()
            .verify.isShowingUpsellModal(ofType: .profiles)
    }
    
    @MainActor
    func testRecommendedProfiles() {
        loginAndOpenProfiles(as: UserType.Free.credentials)
            .verify.recommendedProfilesAreVisible()
    }

    private func loginAndOpenProfiles(as credentials: Credentials) -> ProfileRobot {
        return loginRobot
            .enterCredentials(credentials)
            .signIn(robot: HomeRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .verify.isOnProfilesScreen()
    }
}
