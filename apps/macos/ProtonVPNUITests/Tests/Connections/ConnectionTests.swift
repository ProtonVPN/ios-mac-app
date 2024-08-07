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
        
        let protectedIpAddress = try await checkIpAddressChanged(previousIpAddress: unprotectedIpAddress)
        
        mainRobot
            .disconnect()
            .verify
            .checkConnectionCardIsDisconnected()
        
        try await checkIpAddressChanged(previousIpAddress: protectedIpAddress)
    }
    
    @MainActor
    func testConnectAndCancel() async throws {
        let unprotectedIpAddress = try await NetworkUtils.getIpAddress()
        
        mainRobot
            .verify.checkConnectionCardIsDisconnected()
            .quickConnectToAServer()
            .cancelConnecting()
            .verify.checkConnectionCardIsDisconnected()
        
        try await checkIpAddressUnchanged(previousIpAddress: unprotectedIpAddress)
    }
    
    @MainActor
    func testConnectToSpecificCountry() {
        
        let country = "Australia"
        
        countriesSelectionRobot
            .searchForServer(serverName: country)
            .verify.checkCountryFound(country: country)
            .connectToServer(server: country)
        
        waitForConnected(with: ConnectionProtocol.Smart)
        
        mainRobot
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, to: country)
    }
    
    @MainActor
    func testConnectToSpecificCity() {
        
        let country = "Australia"
        let city = "Melbourne"
        
        countriesSelectionRobot
            .searchForServer(serverName: city)
            .verify.checkCountryFound(country: country)
            .expandCountry(country: country)
            .verify.checkCityFound(city: city)
            .connectToServer(server: city)
        
        waitForConnected(with: ConnectionProtocol.Smart)
        
        mainRobot
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, to: country)
    }
    
    @MainActor
    func testConnectToSpecificServer() {
        
        let country = "Australia"
        let server = "AU#211"
        
        countriesSelectionRobot
            .searchForServer(serverName: server)
            .verify.checkCountryFound(country: country)
            .expandCountry(country: country)
            .verify.checkServerFound(server: server)
            .connectToServer(server: server)
        
        waitForConnected(with: ConnectionProtocol.Smart)
        
        mainRobot
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, to: country)
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
        
        waitForConnected(with: connectionProtocol)
        
        mainRobot
            .verify.checkConnectionCardIsConnected(with: connectionProtocol)
    }
    
    private func checkIpAddressChanged(previousIpAddress: String) async throws -> String {
        let currentIpAddress = try await NetworkUtils.getIpAddress()
        XCTAssertTrue(currentIpAddress != previousIpAddress, "IP address is not changed. Previous ip address: \(previousIpAddress), current IP address: \(currentIpAddress)")
        return currentIpAddress
    }
    
    private func checkIpAddressUnchanged(previousIpAddress: String) async throws {
        let currentIpAddress = try await NetworkUtils.getIpAddress()
        XCTAssertEqual(currentIpAddress, previousIpAddress, "IP address has been changed. Previous ip address: \(previousIpAddress), current IP address: \(currentIpAddress)")
    }
    
    private func waitForConnected(with connectionProtocol: ConnectionProtocol) {
        let connectingTimeout = 5
        guard mainRobot.waitForInitializingConnectionScreenDisappear(connectingTimeout) else {
            XCTFail("VPN is not connected using \(connectionProtocol) in \(connectingTimeout) seconds")
            return
        }
        
        _ = mainRobot.waitForSuccessfullyConnectedScreenDisappear(connectingTimeout)
        
        if mainRobot.isConnectionTimedOut() {
            XCTFail("Connection timeout while connecting to \(connectionProtocol) protocol")
        }
    }
}
