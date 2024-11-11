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

class ConnectionTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    private let connectionStatusRobot = ConnectionStatusRobot()
    private let countryListRobot = CountryListRobot()
    private let countrySearchRobot = CountrySearchRobot()
    private let serverListRobot = ServerListRobot()
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    @MainActor
    func testConnectAndDisconnectViaQCButtonFreeUser() {
        
        loginRobot
            .enterCredentials(UserType.Free.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    @MainActor
    func testConnectAndDisconnectViaCountry() async throws {
        
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        let back = "Countries"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        
        mainRobot
            .goToCountriesTab()
            .searchForServer(serverName: countryName)
            .verify.serverFound(server: countryName)
            .hitPowerButton(server: countryName)
        
        connectionStatusRobot
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .searchForServer(serverName: countryName)
            .hitPowerButton(server: countryName)
            .clearSearch()
        
        mainRobot
            .backToPreviousTab(robot: ConnectionStatusRobot.self, back)
            .verify.connectionStatusNotConnected()
    }
    
    @MainActor
    func testConnectAndDisconnectViaServer() async throws {
        
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .openServerList(countryName)
            .verify.serverListIsOpen(countryName)
            .connectToAServerViaServer()
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: ServerListRobot.self, countryName)
            .verify.serverListIsOpen(countryName)
            .disconnectFromAServerViaServer()
            .verify.connectionStatusNotConnected()
    }
    
    @MainActor
    func testConnectAndDisconnectViaMap() {
        let map = "Map"
        
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        
        mainRobot
            .goToMapTab()
            .selectCountryAndConnect()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .backToPreviousTab(robot: MapRobot.self, map)
            .selectCountryAndDisconnect()
            .verify.connectionStatusNotConnected()
    }
    
    @MainActor
    func testConnectAndDisconnectViaProfile() async throws {
        
        let profileName = StringUtils.randomAlphanumericString()
        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        let back = "Profiles"
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToProfilesTab()
            .tapAddNewProfile()
            .setProfileDetails(profile: profileName, country: countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
            .connectToAProfile(profileName)
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: ConnectionStatusRobot.self, back)
            .verify.connectionStatusConnected(robot: ProfileRobot.self)
            .disconnectFromAProfile(profileName)
            .verify.connectionStatusNotConnected()
    }
    
    @MainActor
    func testConnectAndDisconnectViaFastestAndRandomProfile() {
        
        let back = "Profiles"
        
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToProfilesTab()
            .connectToAFastestServer()
            .verify.qcButtonConnected()
            .backToPreviousTab(robot: ProfileRobot.self, back)
            .disconnectFromAFastestServer()
            .verify.qcButtonDisconnected()
            .backToPreviousTab(robot: ProfileRobot.self, back)
            .connectToARandomServer()
            .verify.qcButtonConnected()
            .backToPreviousTab(robot: ProfileRobot.self, back)
            .disconnectFromARandomServer()
            .verify.qcButtonDisconnected()
    }
    
    @MainActor
    func testConnectionWithDefaultAndSecureCoreProfile() async throws {
        
        let profileName = StringUtils.randomAlphanumericString()
        let randomSecureCoreCountry = try await ServersListUtils.getRandomCountry(secureCore: true)
        let serverVia: String = try await ServersListUtils.getEntryCountries(for: randomSecureCoreCountry.code).first ?? ""
        let status = "\(serverVia) >> \(randomSecureCoreCountry.name)"
    
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToProfilesTab()
            .tapAddNewProfile()
            .setProfileDetails(profile: profileName, country: randomSecureCoreCountry.name, server: serverVia, secureCoreState: true)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated(profile: profileName)
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectedToASecureCoreServer(status)
            .verify.connectedToAProfile()
            .quickDisconnectViaQCButton()
        }
    
    @MainActor
    func testConnectToAPlusServerWithFreeUser() async throws {

        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        
        loginRobot
            .enterCredentials(UserType.Free.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToAPlusCountry(countryName)
            .verify.upgradeSubscriptionScreenOpened()
    }
    
    @MainActor
    func testLogoutWhileConnectedToVPNServer() async throws {
        
        let (countryName, _) = try await ServersListUtils.getRandomCountry()

        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .searchForServer(serverName: countryName)
            .verify.serverFound(server: countryName)
            .hitPowerButton(server: countryName)
        
        connectionStatusRobot
            .verify.connectedToAServer(countryName)
            .goToSettingsTab()
            .logOut()
            .verify.logOutSuccessfully()
    }
    
    @MainActor
    func testCancelLogoutWhileConnectedToVpn() {
            
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .goToSettingsTab()
            .cancelLogOut()
            .verify.connectionStatusConnected(robot: ConnectionStatusRobot.self)
            .disconnectFromAServer()
    }

    @MainActor
    func testConnectionViaSecureCore() {
        
        let protocolName = ConnectionProtocol.WireGuardUDP
        let back = "Countries"

        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(protocolName)
            .returnToSettings()
        mainRobot
            .goToCountriesTab()
            .secureCoreOn()
        
        let firstSecureCoreCountry = countryListRobot.getFirstServerFromList()
        
        countryListRobot
            .connectToFirstCountryFromList()
            .verify.connectedToASecureCoreServer(firstSecureCoreCountry)
            .verify.protocolNameIsCorrect(protocolName)
            .disconnectFromAServer()
            .verify.connectionStatusNotConnected()
        mainRobot
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .secureCoreOFf()
    }
    
    @MainActor
    func testConnectionWithAllSettingsOn() {
        
        let protocolName = ConnectionProtocol.Smart
        let netshield = "Block malware, ads, & trackers"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(protocolName)
            .returnToSettings()
            .selectNetshield(netshield)
            .turnKillSwitchOn()
            .turnModerateNatOn()
        mainRobot
            .goToCountriesTab()
            .secureCoreOn()
        
        let firstSecureCoreCountry = countryListRobot.getFirstServerFromList()
        
        countryListRobot
            .connectToFirstCountryFromList()
            .verify.connectedToASecureCoreServer(firstSecureCoreCountry)
            .verify.protocolNameIsCorrect(protocolName)
            .disconnectFromAServer()
            .verify.connectionStatusNotConnected()
    }
    
    @MainActor
    func testConnectionViaAllProtocolsWithKsOn() {
        
        let back = "Settings"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        
        // WireGuard - UDP
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(ConnectionProtocol.WireGuardUDP)
            .returnToSettings()
            .turnKillSwitchOn()
        mainRobot
            .quickConnectViaQCButton()
            .verify.protocolNameIsCorrect(ConnectionProtocol.WireGuardUDP)
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
        
        // WireGuard - TCP
            .backToPreviousTab(robot: SettingsRobot.self, back)
            .goToProtocolsList()
            .chooseProtocol(ConnectionProtocol.WireGuardTCP)
            .returnToSettings()
        mainRobot
            .quickConnectViaQCButton()
            .verify.protocolNameIsCorrect(ConnectionProtocol.WireGuardTCP)
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
        
        // Stealth
            .backToPreviousTab(robot: SettingsRobot.self, back)
            .goToProtocolsList()
            .chooseProtocol(ConnectionProtocol.Stealth)
            .returnToSettings()
        mainRobot
            .quickConnectViaQCButton()
            .verify.protocolNameIsCorrect(ConnectionProtocol.Stealth)
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
        
        // Smart
            .backToPreviousTab(robot: SettingsRobot.self, back)
            .goToProtocolsList()
            .chooseProtocol(ConnectionProtocol.Smart)
            .returnToSettings()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    @MainActor
    func testReconnectionViaWithKsOn() async throws {
        let (countryToReconnectName, _) = try await ServersListUtils.getRandomCountry()

        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: ConnectionStatusRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .turnKillSwitchOn()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .goToCountriesTab()
            .openServerList(countryToReconnectName)
            .verify.serverListIsOpen(countryToReconnectName)
            .connectToAServerViaServer()
            .verify.connectedToAServer(countryToReconnectName)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
}
