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
import ProtonCoreEnvironment

final class LoginExternalAccountTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()
    
    override func setUp() {
            super.setUp()
            setupAtlasEnvironment()
            mainRobot
                .showLogin()
                .verify.loginScreenIsShown()
        }
        
        lazy var environment: Environment = {
            guard let host = dynamicHost else {
                return .black
            }

            return .custom(host)
        }()
    
    @MainActor
    func testSignInWithInternalAccountWorks() async throws {
        try await QuarkCommands.unbanAsync(currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        try await QuarkCommands.createAsync(account: .freeWithAddressAndKeys(username: randomUsername, password: randomPassword),
                                            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

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
    
    @MainActor
    func testSignInWithExternalAccountWorks() async throws {
        try await QuarkCommands.unbanAsync(currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        try await QuarkCommands.createAsync(account: .external(email: randomEmail, password: randomPassword),
                                            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

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
    
    @MainActor
    func testSignInWithUsernameAccountWorks() async throws {
        try await QuarkCommands.unbanAsync(currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        try await QuarkCommands.createAsync(account: .freeNoAddressNoKeys(username: randomUsername, password: randomPassword),
                                            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())


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
