//
//  Created on 2022-12-07.
//
//  Copyright (c) 2022 Proton AG
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
import ProtonCoreTestingToolkitUITestsLogin
import ProtonCoreQuarkCommands

class TokenRefreshTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    func testLogInExpireSessionAndRefreshTokenGetUserRefreshTokenFailure() throws {
        let user = User(name: StringUtils().randomAlphanumericString(length: 10), password: "123")
        try quarkCommands.userCreate(user: user)

        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()

        _ = try quarkCommands.userExpireSession(username: user.name, expireRefreshToken: true)

        SettingsRobot()
            .goToAccountDetail()
            .deleteAccount()
            .verify.userIsLoggedOut()
    }

    func testLogInExpireSessionGetUserRefreshTokenSuccess() throws {
        let user = User(name: StringUtils().randomAlphanumericString(length: 10), password: "123")
        try quarkCommands.userCreate(user: user)

        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()

        _ = try quarkCommands.userExpireSession(username: user.name, expireRefreshToken: false)

        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .deleteAccount()
            .verify.deleteAccountScreen()
    }
}
