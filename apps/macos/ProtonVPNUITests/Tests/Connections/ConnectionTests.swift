//
//  Created on 16/7/24.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import XCTest

class ConnectionTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let settingsRobot = SettingsRobot()
    private let loginRobot = LoginRobot()
    private let countriesSelectionRobot = CountriesSectionRobot()
    private let alertRobot = AlertRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        loginAsPlusUser()
    }
    
    override func tearDown() {
        super.tearDown()
        if mainRobot.isConnected() {
            mainRobot.disconnect()
        } else if mainRobot.isConnecting() || mainRobot.isConnectionTimedOut() {
            mainRobot.cancelConnecting()
        }
    }
    
    @MainActor
    func testConnectViaWireGuardUdp() {
        performProtocolConnectionTest(withProtocol: ConnectionProtocol.WireGuardUDP)
    }
    
    @MainActor
    func testConnectViaWireGuardTcp() {
        performProtocolConnectionTest(withProtocol: ConnectionProtocol.WireGuardTCP)
    }
    
    @MainActor
    func testConnectViaSmartProtocol() {
        performProtocolConnectionTest(withProtocol: ConnectionProtocol.Smart)
    }
    
    @MainActor
    func testConnectViaStealthProtocol() {
        performProtocolConnectionTest(withProtocol: ConnectionProtocol.Stealth)
    }
    
    @MainActor
    func testConnectViaIKEv2Protocol() {
        performProtocolConnectionTest(withProtocol: ConnectionProtocol.IKEv2)
    }
    
    @MainActor
    func testConnectAndDisconnect() async throws {
        let unprotectedIpAddress = try await NetworkUtils.getIpAddress()
        
        mainRobot
            .quickConnectToAServer()
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
        
        sleep(2)
        
        let protectedIpAddress = try await mainRobot.verify.checkIpAddressChanged(previousIpAddress: unprotectedIpAddress)
        
        mainRobot
            .disconnect()
            .verify
            .checkConnectionCardIsDisconnected()
        
        try await mainRobot.verify.checkIpAddressChanged(previousIpAddress: protectedIpAddress)
    }
    
    @MainActor
    func testConnectAndCancel() async throws {
        let unprotectedIpAddress = try await NetworkUtils.getIpAddress()
        
        mainRobot
            .verify.checkConnectionCardIsDisconnected()
            .quickConnectToAServer()
            .cancelConnecting()
            .verify.checkConnectionCardIsDisconnected()
        
        try await mainRobot.verify.checkIpAddressUnchanged(previousIpAddress: unprotectedIpAddress)
    }
    
    @MainActor
    func testConnectToSpecificCountry() async throws {
        
        let country = try await ServersListUtils.getRandomCountryName()
        
        countriesSelectionRobot
            .searchForServer(serverName: country)
            .verify.checkAmountOfLocationsFound(expectedAmount: 1)
            .verify.checkCountryExists(country)
            .connectToServer(server: country)
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, to: country)
    }
    
    @MainActor
    func testConnectToSpecificCity() async throws {
        
        let (country, city, _) = try await ServersListUtils.getRandomServerInfo()
        
        countriesSelectionRobot
            .searchForServer(serverName: city)
            .verify.checkAmountOfLocationsFound(expectedAmount: 1)
            .verify.checkCountryExists(country)
            .expandCountry(country: country)
            .verify.checkServerListContain(server: city)
            .connectToServer(server: city)
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, to: country)
    }
    
    @MainActor
    func testConnectToSpecificServer() async throws {
        
        let (country, _, server) = try await ServersListUtils.getRandomServerInfo()
        
        countriesSelectionRobot
            .searchForServer(serverName: server)
            .verify.checkAmountOfLocationsFound(expectedAmount: 1)
            .verify.checkCountryExists(country)
            .expandCountry(country: country)
            .verify.checkServerListContain(server: server)
            .connectToServer(server: server)
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, to: country)
    }
    
    @MainActor
    func testLocalNetworkIsReachableWhileConnected() async throws {
        let defaultGatewayAddress = try NetworkUtils.getDefaultGatewayAddress()
        
        try await mainRobot
            .quickConnectToAServer()
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
            .verify.checkIfLocalNetworkingReachable(to: defaultGatewayAddress)
    }
    
    @MainActor
    func testLogoutWhileConnectedContinue() {
        
        mainRobot
            .quickConnectToAServer()
            .waitForConnected(with: ConnectionProtocol.Smart)
            .logOut()
        
        alertRobot
            .verify.checkLogoutWarningAlertAppear()
            .logoutWarningAlert.clickContinue()
        
        loginRobot
            .verify.checkLoginScreenIsShown()
    }
    
    @MainActor
    func testLogoutWhileConnectedCancel() {
        
        mainRobot
            .quickConnectToAServer()
            .waitForConnected(with: ConnectionProtocol.Smart)
            .logOut()
        
        alertRobot
            .verify.checkLogoutWarningAlertAppear()
            .logoutWarningAlert.clickCancel()
        
        mainRobot
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
    }
    
    @MainActor
    private func performProtocolConnectionTest(withProtocol connectionProtocol: ConnectionProtocol) {
        
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .selectProtocol(connectionProtocol)
            .verify.checkProtocolSelected(connectionProtocol)
            .closeSettings()
            .quickConnectToAServer()
            .waitForConnected(with: connectionProtocol)
            .verify.checkConnectionCardIsConnected(with: connectionProtocol)
    }
}
