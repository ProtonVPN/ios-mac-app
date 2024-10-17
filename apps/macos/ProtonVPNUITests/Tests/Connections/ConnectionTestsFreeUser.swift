//
//  Created on 22/8/24.
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
import Modals
import UITestsHelpers

class ConnectionTestsFreeUser: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()
    private let countriesSelectionRobot = CountriesSectionRobot()
    private let modalsRobot = ModalsRobot()

    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        loginAsFreeUser()
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
    func testConnectAndDisconnect() async throws {
        let unprotectedIpAddress = try await NetworkUtils.getIpAddress()
        
        mainRobot
            .quickConnectToAServer()
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, userType: .Free)
        
        sleep(2)
        
        let protectedIpAddress = try await mainRobot.verify.checkIpAddressChanged(previousIpAddress: unprotectedIpAddress)
        
        mainRobot
            .disconnect()
            .verify
            .checkConnectionCardIsDisconnected()
        
        try await mainRobot.verify.checkIpAddressChanged(previousIpAddress: protectedIpAddress)
    }
    
    @MainActor
    func testChangeServer() {
        
        mainRobot
            .quickConnectToAServer()
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, userType: .Free)
        
        let connectedFreeServer = mainRobot.getConnectedCountry()
        
        if mainRobot.isAbleToChangeServer() {
            mainRobot
                .clickChangeServer()
                .waitForConnected(with: ConnectionProtocol.Smart)
                .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart, userType: .Free)
            
            mainRobot
                .verify.checkConnectedServerChanged(connectedServer: connectedFreeServer)
        } else {
            mainRobot
                .clickChangeServer()
            
            modalsRobot
                .verify.checkModalAppear(type: ModalType.cantSkip)
                .closeModal()
        }
    }
}

