//
//  Created on 2023-09-25.
//
//  Copyright (c) 2023 Proton AG
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

import fusion
import ProtonCoreTestingToolkitUITestsLogin
import ProtonCoreQuarkCommands

final class LoginExternalAccountTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    func testSignInWithInternalAccountWorks() throws {
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        let user = User(name: randomUsername, password: randomPassword)

        try quarkCommands.userCreate(user: user)

        _ = SigninExternalAccountsCapability()
            .signInWithAccount(
                userName: randomUsername,
                password: randomPassword,
                loginRobot: ProtonCoreTestingToolkitUITestsLogin.LoginRobot(),
                retRobot: MainRobot.self
            )
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
        loginRobot
            .verify.correctUserIsLogedIn(.init(username: randomUsername, password: randomPassword, plan: "Proton VPN Free"))
    }

    func testSignInWithExternalAccountWorks() throws {

        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@gmail.com"
        let randomName = "\(StringUtils().randomAlphanumericString(length: 8))"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        let user = User(email: randomEmail, name: randomName, password: randomPassword, isExternal: true)

        try quarkCommands.userCreate(user: user)

        _ = SigninExternalAccountsCapability()
            .signInWithAccount(
                userName: randomEmail,
                password: randomPassword,
                loginRobot: ProtonCoreTestingToolkitUITestsLogin.LoginRobot(),
                retRobot: MainRobot.self
            )
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
        loginRobot
            .verify.correctUserIsLogedIn(.init(username: randomEmail, password: randomPassword, plan: "Proton VPN Free"))
    }

    func testSignInWithUsernameAccountWorks() throws {
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        let user = User(name: randomUsername, password: randomPassword)

        try quarkCommands.userCreate(user: user, createAddress: CreateAddress.noKey)

        _ = SigninExternalAccountsCapability()
            .signInWithAccount(
                userName: randomUsername,
                password: randomPassword,
                loginRobot: ProtonCoreTestingToolkitUITestsLogin.LoginRobot(),
                retRobot: MainRobot.self
            )
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
        loginRobot
            .verify.correctUserIsLogedIn(.init(username: randomUsername, password: randomPassword, plan: "Proton VPN Free"))
    }
}
