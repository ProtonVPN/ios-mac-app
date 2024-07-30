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
    func performProtocolConnectionTest(withProtocol connectionProtocol: ConnectionProtocol) {
        
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .selectProtocol(connectionProtocol)
            .verify.checkProtocolSelected(connectionProtocol)
            .closeSettings()
            .quickConnectToAServer()
        
        let connectingTimeout = 30
        guard mainRobot.waitForConnectingFinish(connectingTimeout) else {
            XCTFail("VPN is not connected using \(connectionProtocol) in \(connectingTimeout) seconds")
            return
        }
        
        if mainRobot.isConnectionTimedOut() {
            XCTFail("Connection timeout while connecting to \(connectionProtocol) protocol")
        }
        
        mainRobot
            .verify.checkVPNConnected(with: connectionProtocol)
    }
}
