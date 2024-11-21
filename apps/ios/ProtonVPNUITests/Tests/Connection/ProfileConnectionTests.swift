//
//  ConnectionTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import fusion
import ProtonCoreTestingToolkitUITestsLogin
import UITestsHelpers
import XCTest

@MainActor
class ProfileConnectionTests: ConnectionTestsBase {

    func testConnectAndDisconnectViaProfile() async throws {
        
        let profileName = StringUtils.randomAlphanumericString()
        let (countryName, _) = try await ServersListUtils.getRandomCountry()

        login(as: UserType.Plus.credentials)
            .goToProfilesTab()
            .tapAddNewProfile()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .connectToAProfile(profileName)
            .verify.connectedToAServer(countryName)
            .goToProfilesTab()
            .disconnectFromAProfile(profileName)
        homeRobot
            .goToHomeTab()
            .verify.connectionStatusNotConnected()
    }

    func testConnectAndDisconnectViaFastestAndRandomProfile() {
        
        login(as: UserType.Plus.credentials)
            .goToProfilesTab()
            .connectToAFastestServer()
            .verify.connectionStatusConnected()
            .goToProfilesTab()
            .disconnectFromAFastestServer()
            .goToHomeTab(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
            .goToProfilesTab()
            .connectToARandomServer()
            .verify.connectionStatusConnected()
            .goToProfilesTab()
            .disconnectFromARandomServer()
            .goToHomeTab(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
    }

    func testConnectionWithDefaultAndSecureCoreProfile() async throws {
        
        let profileName = StringUtils.randomAlphanumericString()
        let randomSecureCoreCountry = try await ServersListUtils.getRandomCountry(secureCore: true)
        let serverVia: String = try await ServersListUtils.getEntryCountries(for: randomSecureCoreCountry.code).first ?? ""
        let status = "\(randomSecureCoreCountry.name), via \(serverVia)"

        login(as: UserType.Plus.credentials)
            .goToProfilesTab()
            .tapAddNewProfile()
            .setProfileDetails(profile: profileName, country: randomSecureCoreCountry.name, server: serverVia, secureCoreState: true)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .connectToAProfile(profileName)
            .verify.connectionStatusConnected(robot: ConnectionStatusRobot.self)
            .verify.connectedToASecureCoreServer(status)
        homeRobot
            .quickDisconnectViaQCButton()
            .verify.connectionStatusNotConnected()
        }

    func testLogoutWhileConnectedToVPNServer() async throws {
        
        let (countryName, _) = try await ServersListUtils.getRandomCountry()

        login(as: UserType.Plus.credentials)
            .goToCountriesTab()
            .searchForServer(serverName: countryName)
            .verify.serverFound(server: countryName)
            .hitPowerButton(server: countryName)
            .verify.connectedToAServer(countryName)
            .goToSettingsTab()
            .logOut()
            .verify.logOutSuccessfully()
    }
    
    func testCancelLogoutWhileConnectedToVpn() {

        login(as: UserType.Plus.credentials)
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected()
            .goToSettingsTab()
            .cancelLogOut()
            .goToHomeTab()
            .verify.connectionStatusConnected()
    }
}
