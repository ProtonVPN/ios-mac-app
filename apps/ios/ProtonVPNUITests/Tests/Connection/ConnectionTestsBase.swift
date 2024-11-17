//
//  Created on 19/11/24.
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
import fusion
import ProtonCoreTestingToolkitUITestsLogin
import UITestsHelpers
import XCTest

class ConnectionTestsBase: ProtonVPNUITests {

    let loginRobot = LoginRobot()
    let connectionStatusRobot = ConnectionStatusRobot()
    let countryListRobot = CountryListRobot()
    let countrySearchRobot = CountrySearchRobot()
    let serverListRobot = ServerListRobot()

    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        homeRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    override func tearDown() {
        disconnectIfNeeded()
        super.tearDown()
    }

    func disconnectIfNeeded() {
        if connectionStatusRobot.isConnected() {
            homeRobot.quickDisconnectViaQCButton()
        }
    }

    @discardableResult
    func login(as userCredentials: Credentials) -> HomeRobot {
        loginRobot
            .enterCredentials(userCredentials)
            .signIn(robot: LoginRobot.self)
            .verify.loginScreenIsNotShown()
        disconnectIfNeeded()
        connectionStatusRobot
            .verify.connectionStatusNotConnected()
        return homeRobot
    }
}
