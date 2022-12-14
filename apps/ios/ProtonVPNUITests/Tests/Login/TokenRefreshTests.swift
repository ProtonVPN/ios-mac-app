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
import ProtonCore_TestingToolkit
import ProtonCore_QuarkCommands
import ProtonCore_Doh

class TokenRefreshTests: ProtonVPNUITests {
    
    var doh: DoH & ServerConfig {
          return CustomServerConfigDoH(
            signupDomain: ObfuscatedConstants.blackSignupDomain,
            captchaHost: ObfuscatedConstants.blackCaptchaHost,
            humanVerificationV3Host: ObfuscatedConstants.blackHumanVerificationV3Host,
            accountHost: ObfuscatedConstants.blackAccountHost,
            defaultHost: ObfuscatedConstants.blackDefaultHost,
            apiHost: ObfuscatedConstants.apiHost,
            defaultPath: ObfuscatedConstants.blackDefaultPath
          )
      }
    
    lazy var quarkCommands = QuarkCommands(doh: doh)
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()
    private let credentialsBF22 = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials_bf22", withExtension: "plist")!)
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    @MainActor
    func testExpireSessionAndRefreshToken() async throws {
        loginRobot
            .loginAsUser(credentialsBF22[0])
            .signIn(robot: MainRobot.self)
            .verify.qcButtonDisconnected()
        try await quarkCommands.expireSessionAsync(username: credentialsBF22[0].username, expireRefreshToken: true)
        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .deleteAccount()
            .verify.userIsLoggedOut()
    }

    @MainActor
    func testExpireSessionToken() async throws {
        loginRobot
            .loginAsUser(credentialsBF22[0])
            .signIn(robot: MainRobot.self)
            .verify.qcButtonDisconnected()
        try await quarkCommands.expireSessionAsync(username: credentialsBF22[0].username)
        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .deleteAccount()
            .verify.deleteAccountScreen()
    }
}
