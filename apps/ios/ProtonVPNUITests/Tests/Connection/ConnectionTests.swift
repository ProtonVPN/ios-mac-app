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

class ConnectionTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    private let connectionStatusRobot = ConnectionStatusRobot()
    private let countryListRobot = CountryListRobot()
    private let serverListRobot = ServerListRobot()
    private let settingsRobot = SettingsRobot()
    
    private lazy var credentials = getCredentials(from: "credentials")
    
    enum CredentialsKey: Int {
        case freeUser = 0
        case basicUser = 1
        case plusUser = 2
    }
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testConnectAndDisconnectViaQCButtonFreeUser() {
        
        loginRobot
            .enterCredentials(credentials[0])
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
            .enterCredentials(credentials[CredentialsKey.basicUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .disconnectViaCountry()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaServer() {
        
        let countryName = "Australia"
        
        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
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
        
        let countryName = "Netherlands"
        let map = "Map"
        
        loginRobot
            .enterCredentials(credentials[CredentialsKey.plusUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToMapTab()
            .selectCountryAndConnect()
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: MapRobot.self, map)
            .selectCountryAndDisconnect()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaProfile() {
        
        let profileName = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Argentina"
        let back = "Profiles"
        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
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
            .enterCredentials(credentials[CredentialsKey.basicUser])
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
        
        let profileName = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Ukraine"
        let serverVia = "Switzerland"
        let status = "Switzerland >> Ukraine"
    
        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
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
            .verify.connectedToASCServer(status)
            .verify.connectedToAProfile()
            .quickDisconnectViaQCButton()
        }
    
    func testConnectToAPlusServerWithFreeUser() {

        let countryName = "Austria"
        
        loginRobot
            .enterCredentials(credentials[CredentialsKey.freeUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToAPlusCountry(countryName)
            .verify.upgradeSubscriptionIsOpenFreeUser()
    }
    
    func testLogoutWhileConnectedToVPNServer() {
        
        let countryName = "Netherlands"

        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
            .verify.connectedToAServer(countryName)
            .goToSettingsTab()
            .logOut()
            .verify.logOutSuccessfully()
    }
    
    func testCancelLogoutWhileConnectedToVpn() {
            
        loginRobot
            .enterCredentials(credentials[CredentialsKey.plusUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .goToSettingsTab()
            .cancelLogOut()
            .verify.connectionStatusConnected(robot: ConnectionStatusRobot.self)
            .disconnectFromAServer()
    }

    func testConnectionViaSC() {
        
        let protocolVia = "WireGuard"
        let status = "Sweden >> Australia"
        let back = "Countries"

        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .protocolOn(protocolVia)
            .returnToSettings()
        mainRobot
            .goToCountriesTab()
            .secureCoreOn()
            .connectToAServer()
            .verify.connectedToASCServer(status)
            .verify.protocolNameIsCorrect(protocolVia)
            .disconnectFromAServer()
            .verify.connectionStatusNotConnected()
        mainRobot
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .secureCoreOFf()
    }
    
    func testConnectionWithAllSettingsOn() {
        
        let protocolVia = "Smart"
        let netshield = "Block malware, ads, & trackers"
        let status = "Sweden >> Australia"
        
        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .protocolOn(protocolVia)
            .returnToSettings()
            .selectNetshield(netshield)
            .turnKillSwitchOn()
            .turnModerateNatOn()
        mainRobot
            .goToCountriesTab()
            .secureCoreOn()
            .connectToAServer()
            .verify.connectedToASCServer(status)
            .disconnectFromAServer()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectionViaAllProtocolsWithKsOn() { // swiftlint:disable:this function_body_length
        
        let countryName = "Australia"
        let protocolViaWG = "WireGuard"
        let protocolViaUDP = "OpenVPN (UDP)"
        let protocolViaTCP = "OpenVPN (TCP)"
        let protocolViaSmart = "Smart"
        let back = "Settings"
        
        loginRobot
            .enterCredentials(credentials[CredentialsKey.basicUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .protocolOn(protocolViaWG)
            .returnToSettings()
            .turnKillSwitchOn()
        mainRobot
            .quickConnectViaQCButton()
            .verify.protocolNameIsCorrect(protocolViaWG)
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
            .backToPreviousTab(robot: SettingsRobot.self, back)
            .goToProtocolsList()
            .protocolOn(protocolViaUDP)
            .returnToSettings()
        mainRobot
            .quickConnectViaQCButton()
            .verify.protocolNameIsCorrect(protocolViaUDP)
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
            .backToPreviousTab(robot: SettingsRobot.self, back)
            .goToProtocolsList()
            .protocolOn(protocolViaTCP)
            .returnToSettings()
        mainRobot
            .quickConnectViaQCButton()
            .verify.protocolNameIsCorrect(protocolViaTCP)
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
            .backToPreviousTab(robot: SettingsRobot.self, back)
            .goToProtocolsList()
            .protocolOn(protocolViaSmart)
            .returnToSettings()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    func testReconnectionViaWithKsOn() {
        
        let countryName = "Japan"

        loginRobot
            .enterCredentials(credentials[CredentialsKey.freeUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
            .turnKillSwitchOn()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .goToCountriesTab()
            .openServerList(countryName)
            .verify.serverListIsOpen(countryName)
            .connectToAServerViaServer()
            .verify.connectedToAServer(countryName)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
}
