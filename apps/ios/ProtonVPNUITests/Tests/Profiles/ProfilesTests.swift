//
//  ProfilesTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import ProtonCoreTestingToolkitUITestsLogin
import UITestsHelpers
import XCTest

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
    func testCreateAndDeleteProfile() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: HomeRobot.self)
            .verify.isLoggedIn()
            .goToCountriesTab()

        let countryName = CountryListRobot().getRandomServerFromList()

        homeRobot
            .goToProfilesTab()
            .tapAddNewProfile()
            .verify.isOnProfilesEditScreen()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .deleteProfile(profileName)
            .verify.profileIsDeleted(profileName)
    }

    @MainActor
    func testCreateProfileWithTheSameName() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)

        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: HomeRobot.self)
            .verify.isLoggedIn()
            .goToCountriesTab()

        let countryName = CountryListRobot().getRandomServerFromList()

        homeRobot
            .goToProfilesTab()
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
    func testEditProfile() {
        let profileName = StringUtils.randomAlphanumericString(length: 10)
        let newProfileName = StringUtils.randomAlphanumericString(length: 10)

        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: HomeRobot.self)
            .verify.isLoggedIn()
            .goToCountriesTab()

        let countryName = CountryListRobot().getRandomServerFromList()
        let newCountryName = CountryListRobot().getRandomServerFromList()

        homeRobot
            .goToProfilesTab()
            .tapAddNewProfile()
            .verify.isOnProfilesEditScreen()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .editProfile(profileName)
            .setProfileDetails(profile: newProfileName, country: newCountryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsEdited(profile: newProfileName)
            .deleteProfile(newProfileName)
    }

    @MainActor
    func disabled_testMakeSecureCoreProfilePlusUser() async throws {
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
        loginRobot
            .enterCredentials(credentials)
            .signIn(robot: HomeRobot.self)
            .verify.isLoggedIn()
            .goToProfilesTab()
            .verify.isOnProfilesScreen()
    }
}
