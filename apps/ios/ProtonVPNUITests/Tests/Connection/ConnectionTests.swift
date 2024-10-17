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
    
    func testConnectAndDisconnectViaQCButtonFreeUser() {
        
        loginRobot
            .enterCredentials(UserType.Free.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    func testConnectAndDisconnectViaCountry() {
        
        let countryName = "Australia"
        let back = "Countries"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
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
            .backToPreviousTab(robot: MainRobot.self, back)
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaServer() {
        
        let countryName = "Australia"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
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
    
    func testConnectAndDisconnectViaMap() {
        let map = "Map"
        
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        
        mainRobot
            .goToMapTab()
            .selectCountryAndConnect()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .backToPreviousTab(robot: MapRobot.self, map)
            .selectCountryAndDisconnect()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaProfile() {
        
        let profileName = StringUtils.randomAlphanumericString()
        let countryName = "Argentina"
        let back = "Profiles"
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profileName, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .connectToAProfile(profileName)
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: ProfileRobot.self, back)
            .disconnectFromAProfile()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaFastestAndRandomProfile() {
        
        let back = "Profiles"
        
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
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
    
    func testConnectionWithDefaultAndSecureCoreProfile() {
        
        let profileName = StringUtils.randomAlphanumericString()
        let countryName = "Ukraine"
        let serverVia = "Switzerland"
        let status = "Switzerland >> Ukraine"
    
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .makeDefaultProfileWithSecureCore(profileName, countryName, serverVia)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectedToASecureCoreServer(status)
            .verify.connectedToAProfile()
            .quickDisconnectViaQCButton()
        }
    
    func testConnectToAPlusServerWithFreeUser() {

        let countryName = "Austria"
        
        loginRobot
            .enterCredentials(UserType.Free.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToAPlusCountry(countryName)
            .verify.upgradeSubscriptionScreenOpened()
    }
    
    func testLogoutWhileConnectedToVPNServer() {
        
        let countryName = "Netherlands"

        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
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
    
    func testCancelLogoutWhileConnectedToVpn() {
            
        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToFirstCountryFromList()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .goToSettingsTab()
            .cancelLogOut()
            .verify.connectionStatusConnected(robot: ConnectionStatusRobot.self)
            .disconnectFromAServer()
    }

    func testConnectionViaSecureCore() {
        
        let protocolName = ConnectionProtocol.WireGuardUDP
        let back = "Countries"

        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
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
    
    func testConnectionWithAllSettingsOn() {
        
        let protocolName = ConnectionProtocol.Smart
        let netshield = "Block malware, ads, & trackers"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
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
    
    func testConnectionViaAllProtocolsWithKsOn() { // swiftlint:disable:this function_body_length
        
        let back = "Settings"
        
        loginRobot
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: MainRobot.self)
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
    
    func testReconnectionViaWithKsOn() {
        
        let countryToReconnectName = "Japan"

        loginRobot
            .enterCredentials(UserType.Plus.credentials)
            .signIn(robot: MainRobot.self)
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
