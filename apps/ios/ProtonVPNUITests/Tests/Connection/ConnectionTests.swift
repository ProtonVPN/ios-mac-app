//
//  ConnectionTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class ConnectionTests: ProtonVPNUITests {
    
    private let loginRobot = LoginRobot()
    private let mainRobot = MainRobot()
    private let connectionStatusRobot = ConnectionStatusRobot()
    private let countryListRobot = CountryListRobot()
    private let serverListRobot = ServerListRobot()
    private let settingsRobot = SettingsRobot()
    
    override func setUp() {
        super.setUp()
    }
    
    func testConnectAndDisconnectViaQCButtonFreeUser() {
        
        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsFreeUser()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    func testConnectAndDisconnectViaCountry() {
        
        let countryName = "Australia"
        let back = "Countries"
        
        logInToProdIfNeeded()
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
        
        logoutIfNeeded()
        logInToProdIfNeeded()
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
        
        logInToProdIfNeeded()
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
        
        logInToProdIfNeeded()
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
        
        logInToProdIfNeeded()
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
    
        logInToProdIfNeeded()
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

        let countryName = "Ukraine"
        
        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsFreeUser()
        mainRobot
            .goToCountriesTab()
            .connectToAPlusCountry(countryName)
            .verify.upgradeSubscriptionIsOpenFreeUser()
    }
    
    func testLogoutWhileConnectedToVPNServer() {
        
        let countryName = "Netherlands"

        logInToProdIfNeeded()
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
            .verify.connectedToAServer(countryName)
            .goToSettingsTab()
            .logOut()
            .verify.logOutSuccessfully()
    }
    
    func testCancelLogoutWhileConnectedToVpn() {
            
        logoutIfNeeded()
        logInToProdIfNeeded()
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
            .verify.connectionStatusConnected(robot: MainRobot.self)
            .goToSettingsTab()
            .cancelLogOut()
            .verify.connectionStatusConnected(robot: ConnectionStatusRobot.self)
            .disconnectFromAServer()
    }
    
    func testConnectionViaOpenvpnUDP() {
        
        let protocolVia = "OpenVPN (UDP)"
        let countryName = "Australia"
        let back = "Countries"
        
        logInToProdIfNeeded()
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .protocolOn(protocolVia)
            .returnToSettings()
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
            .verify.protocolNameIsCorrect(protocolVia)
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .disconnectViaCountry()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectionViaOpenvpnTCP() {
           
           let protocolVia = "OpenVPN (TCP)"
           let countryName = "United States"
           let back = "Countries"
           
           logInToProdIfNeeded()
           mainRobot
               .goToSettingsTab()
               .goToProtocolsList()
               .protocolOn(protocolVia)
               .returnToSettings()
           mainRobot
               .goToCountriesTab()
               .connectToAServer()
               .verify.protocolNameIsCorrect(protocolVia)
               .verify.connectedToAServer(countryName)
               .backToPreviousTab(robot: CountryListRobot.self, back)
               .disconnectViaCountry()
               .verify.connectionStatusNotConnected()
       }
    
    func testConnectionViaIkev() {
            
            let protocolVia = "IKEv2"
            let countryName = "Australia"
            let back = "Countries"
        
            logoutIfNeeded()
            logInToProdIfNeeded()
            loginAsFreeUser()
            mainRobot
                .goToSettingsTab()
                .goToProtocolsList()
                .protocolOn(protocolVia)
                .returnToSettings()
            mainRobot
                .goToCountriesTab()
                .connectToAServer()
                .verify.protocolNameIsCorrect(protocolVia)
                .verify.connectedToAServer(countryName)
                .backToPreviousTab(robot: CountryListRobot.self, back)
                .disconnectViaCountry()
                .verify.connectionStatusNotConnected()
        }

    func testConnectionViaSC() {
        
        let protocolVia = "IKEv2"
        let status = "Sweden >> Australia"
        let back = "Countries"
        
        logoutIfNeeded()
        logInToProdIfNeeded()
        loginAsBasicUser()
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
        
        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsBasicUser()
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
        
        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsBasicUser()
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

        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsFreeUser()
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
