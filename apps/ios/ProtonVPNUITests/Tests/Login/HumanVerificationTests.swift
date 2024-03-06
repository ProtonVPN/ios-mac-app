//
//  Created on 06/03/2024.
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
import ProtonCoreTestingToolkitUITestsLogin
import ProtonCoreHumanVerification
import ProtonCoreQuarkCommands

class HumanVerificationTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testLoginWithHumanVerification() throws {
        
        let user = User(name: StringUtils().randomAlphanumericString(length: 5), password: "123")
        try quarkCommands.userCreate(user: user)
        
        try quarkCommands.systemEnvVariableAsJson(variable: "FINGERPRINT_DEV", value: "true")
        try quarkCommands.systemEnvVariableAsJson(variable: "FINGERPRINT_RESPONSE", value: FingerprintResponse.captcha.rawValue)
        
        loginRobot
            .enterCredentials(user)
            .signIn(robot: LoginRobot.self)
            .verifyCaptcha()
        mainRobot
            .verify.connectionStatusNotConnected()
        
        try quarkCommands.systemEnvVariableAsJson(variable: "FINGERPRINT_RESPONSE", value: FingerprintResponse.ok.rawValue)
    }
}
