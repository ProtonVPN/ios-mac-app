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

final class InternalAndExternalSignUpTests: ProtonVPNUITests {

    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
    }

    func testSignUpWithInternalAccountWorks() {
        unbanBeforeSignup(doh: doh)

        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        SignupExternalAccountsCapability()
            .signUpWithInternalAccount(
                signupRobot: ProtonCoreTestingToolkitUITestsLogin.SignupRobot().otherAccountButtonTap(),
                username: randomUsername,
                password: randomPassword,
                userEmail: randomEmail,
                verificationCode: "666666",
                retRobot: CreatingAccountRobot.self)
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown(time: 190)
            .skipFullOnboarding()
        mainRobot
            .goToSettingsTab()
            .verify.userIsCreated(randomUsername, "Proton VPN Free")
    }

    func testSignUpWithExternalAccountWorks() {
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@mailui.co"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        SignupExternalAccountsCapability()
            .signUpWithExternalAccount(
                signupRobot: ProtonCoreTestingToolkitUITestsLogin.SignupRobot(),
                userEmail: randomEmail,
                password: randomPassword,
                verificationCode: "666666",
                retRobot: CreatingAccountRobot.self
            )
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown(time: 190)
            .skipFullOnboarding()
        mainRobot
            .goToSettingsTab()
            .verify.userIsCreated(randomEmail, "Proton VPN Free")
    }
}
