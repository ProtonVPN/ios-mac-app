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
        changeEnvToProdIfNedded()
        openLoginScreen()
        loginAsFreeUser()
        mainRobot
            .quickConnectViaQCbutton()
            .verify.connectedToAServer(countryName)
            .quickDisconnectViaQCbutton()
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
            .backToPreviouseTab(robot: CountryListRobot.self, back)
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
            .backToPreviouseTab(robot: ServerListRobot.self, countryName)
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
            .backToPreviouseTab(robot: MapRobot.self, map)
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
            .backToPreviouseTab(robot: ProfileRobot.self, back)
            .disconnectFromAProfile()
            .verify.connectionStatusNotConnected()
    }
    
    func testConnectAndDisconnectViaFastestAndRandomProfile() {
        
        let back = "Profiles"
        
        logInToProdIfNeeded()
        mainRobot
            .goToProfilesTab()
            .connectToAFastesServer()
            .verify.qcButtonConnected()
            .backToPreviouseTab(robot: ProfileRobot.self, back)
            .disconnectFromAFastesServer()
            .verify.qcButtonDisconnected()
            .backToPreviouseTab(robot: ProfileRobot.self, back)
            .connectToARandomServer()
            .verify.qcButtonConnected()
            .backToPreviouseTab(robot: ProfileRobot.self, back)
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
            .quickConnectViaQCbutton()
            .verify.connectedToASCServer(status)
            .verify.connectedToAProfile()
            .quickDisconnectViaQCbutton()
        }
    
    func testConnectToAPlusServerWithFreeUser() {

        let countryName = "Ukraine"
        
        logoutIfNeeded()
        changeEnvToProdIfNedded()
        openLoginScreen()
        loginAsFreeUser()
        mainRobot
            .goToCountriesTab()
            .connectToAPlusCountry(countryName)
            .verify.upgradeSubscribtionIsOpenFreeUser()
    }
    
    func testConnectToAPlusServerWithBasicUser() {

        let countryName = "Ukraine"
        let serverName = "UA#12"
        
        logoutIfNeeded()
        changeEnvToProdIfNedded()
        openLoginScreen()
        loginAsBasicUser()
        mainRobot
            .goToCountriesTab()
            .openServerList(countryName)
            .connectToAPlusServer(serverName)
            .verify.upgradeSubscribtionIsOpenBasicUser()
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
