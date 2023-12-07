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
import ProtonCoreDoh

class TokenRefreshTests: ProtonVPNUITests {
    
    lazy var quarkCommands = QuarkCommands(doh: doh)
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()
    
    private let user = Credentials(username: StringUtils().randomAlphanumericString(length: 10), password: "123", plan: "vpn2022")

    
    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
        quarkCommands.createUser(username: user.username, password: user.password, protonPlanName: user.plan)
    }

    @MainActor
    func testLogInExpireSessionAndRefreshTokenGetUserRefreshTokenFailure() async throws {
        
        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        mainRobot
            .goToSettingsTab()
        try await quarkCommands.expireSessionAsync(username: user.username, expireRefreshToken: true)
        SettingsRobot()
            .goToAccountDetail()
            .deleteAccount()
            .verify.userIsLoggedOut()
    }

    @MainActor
    func testLogInExpireSessionGetUserRefreshTokenSuccess() async throws {
        loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        try await quarkCommands.expireSessionAsync(username: user.username)
        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .deleteAccount()
            .verify.deleteAccountScreen()
    }
}
