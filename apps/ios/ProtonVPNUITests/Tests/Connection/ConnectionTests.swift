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
    private let settingstRobot = SettingsRobot()
    
    override func setUp() {
        super.setUp()
    }
    
    func testConnectAndDisconnectViaQCButtonFreeUser() {
        
        let countryName = "Netherlands"

        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsFreeUser()
        mainRobot
            .quickConnectViaQCButton()
            .verify.connectedToAServer(countryName)
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    func testConnectAndDisconnectViaCountry() {
        
        let countryName = "Australia"
        let back = "Countries"
        
        logInToProdIfNeeded()
        mainRobot
            .goToCountriesTab()
            .connectToAserver()
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .diconnectViaCountry()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaServer() {
        
        let countryName = "Australia"
        
        logInToProdIfNeeded()
        mainRobot
            .goToCountriesTab()
            .openServerList(countryName)
            .verify.serverListIsOpen(countryName)
            .connectToAServerViaServer()
            .verify.connectedToAServer(countryName)
            .backToPreviousTab(robot: ServerListRobot.self, countryName)
            .verify.serverListIsOpen(countryName)
            .disconectFromAServerViaServer()
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
        
        let profilename = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Argentina"
        let back = "Profiles"
        
        logInToProdIfNeeded()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .setProfileDetails(profilename, countryName)
            .saveProfile(robot: ProfileRobot.self)
            .verify.profileIsCreated()
            .connectToAProfile(profilename)
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
        
        let profilename = StringUtils().randomAlphanumericString(length: 10)
        let countryName = "Ukraine"
        let serverVia = "Switzerland"
        let status = "Switzerland >> Ukraine"
    
        logInToProdIfNeeded()
        mainRobot
            .goToProfilesTab()
            .addNewProfile()
            .makeDefaultProfileWithSecureCore(profilename, countryName, serverVia)
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
    
    func testConnectToAPlusServerWithBasicUser() {

        let countryName = "Ukraine"
        let serverName = "UA#12"
        
        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        openLoginScreen()
        loginAsBasicUser()
        mainRobot
            .goToCountriesTab()
            .openServerList(countryName)
            .connectToAPlusServer(serverName)
            .verify.upgradeSubscriptionIsOpenBasicUser()
    }
    
    func testLogoutWhileConnectedToVPNServer() {
        
        let countryName = "Australia"
        
        logInToProdIfNeeded()
        mainRobot
            .goToCountriesTab()
            .connectToAserver()
            .verify.connectedToAServer(countryName)
            .goToSettingsTab()
            .logOut()
            .verify.logOutSuccessfully()
    }
}
