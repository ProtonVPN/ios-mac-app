//
//  Created on 6/8/24.
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

class AutoConnectTests: ProtonVPNUITests {
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
        
        // wating for loading screen disappear in case app stuck
        waitForLoaderDisappear(60)
        
        if mainRobot.isConnected() {
            mainRobot.disconnect()
        } else if mainRobot.isConnecting() || mainRobot.isConnectionTimedOut() {
            mainRobot.cancelConnecting()
        }
        
        mainRobot
            .openAppSettings()
            .connectionTabClick()
            .selectAutoConnect(AutoConnectOptions.Disabled)
            .closeSettings()
    }
    
    @MainActor
    func testConnectionAutoConnectFastest() {
        
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .selectAutoConnect(AutoConnectOptions.Fastest)
            .verify.checkAutoConnectSelected(AutoConnectOptions.Fastest)
            .closeSettings()
            .verify.checkConnectionCardIsDisconnected()
        
        relaunchApp()
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
        
        let connectedServer1 = mainRobot.getConnectedCountry()
        
        mainRobot
            .disconnect()
        
        relaunchApp()
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
        
        let connectedServer2 = mainRobot.getConnectedCountry()
        
        XCTAssertEqual(connectedServer1, connectedServer2, "App shoudl connect to same server, but connected to different. 1st attempt: \(connectedServer1), 2nd attempt: \(connectedServer2)")
        
    }
    
    @MainActor
    func testConnectionAutoConnectRandom() {
        
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .connectionTabClick()
            .verify.checkConnectionTabIsOpen()
            .selectAutoConnect(AutoConnectOptions.Random)
            .verify.checkAutoConnectSelected(AutoConnectOptions.Random)
            .closeSettings()
            .verify.checkConnectionCardIsDisconnected()
        
        relaunchApp()
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
        
        let connectedServer1 = mainRobot.getHeaderLabelValue()
        
        mainRobot
            .disconnect()
        
        relaunchApp()
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
        
        let connetedServer2 = mainRobot.getConnectedCountry()
        
        XCTAssertNotEqual(connectedServer1, connetedServer2, "App shoudl connect to differend random server, but connected to the same one. 1st attempt: \(connectedServer1), 2nd attempt: \(connetedServer2)")
    }
    
    @MainActor
    func testConnectionAutoConnectDisabled() {
        
        mainRobot
            .openAppSettings()
            .connectionTabClick()
            .selectAutoConnect(AutoConnectOptions.Fastest)
            .verify.checkAutoConnectSelected(AutoConnectOptions.Fastest)
            .selectAutoConnect(AutoConnectOptions.Disabled)
            .verify.checkAutoConnectSelected(AutoConnectOptions.Disabled)
            .closeSettings()
        
        relaunchApp()
        
        mainRobot
            .verify.checkConnectionCardIsDisconnected()
    }
}
