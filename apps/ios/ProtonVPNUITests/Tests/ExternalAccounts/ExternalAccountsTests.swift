//
//  Created on 13/12/2022.
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

import XCTest
import fusion
import ProtonCore_TestingToolkit
import ProtonCore_QuarkCommands
import ProtonCore_CoreTranslation
import ProtonCore_Environment

final class ExternalAccountsTests: ProtonVPNUITests {
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
    }

    lazy var environment: Environment = {
        guard let url = URL(string: dynamicDomain) else {
            return .black
        }
        if #available(iOS 16, *) {
            if let host = url.host() {
                return .custom(host)
            }
        } else {
            if let host = url.host {
                return .custom(host)
            }
        }
        return .black
    }()

    let signInTimeout: TimeInterval = 90
    let signUpTimeout: TimeInterval = 180
    
//    Sign-in:
//    Sign-in with internal account works
//    Sign-in with external account works
//    Sign-in with username account works (no conversion to internal, so no address or keys generation)

    @MainActor
    func testSignInWithInternalAccountWorks() async throws {
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        try await QuarkCommands.createAsync(account: .freeWithAddressAndKeys(username: randomUsername, password: randomPassword),
                                            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        _ = MainRobot()
            .showLogin()
        
        _ = SigninExternalAccountsCapability()
            .signInWithAccount(
                userName: randomUsername,
                password: randomPassword,
                loginRobot: ProtonCore_TestingToolkit.LoginRobot(),
                retRobot: MainRobot.self
            )
        
        correctUserIsLoggedIn(.init(username: randomUsername, password: randomPassword, plan: "Proton VPN Free"))
    }

    @MainActor
    func testSignInWithExternalAccountWorks() async throws {
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        try await QuarkCommands.createAsync(account: .external(email: randomEmail, password: randomPassword),
                                            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())
        
        _ = MainRobot()
            .showLogin()
        
        _ = SigninExternalAccountsCapability()
            .signInWithAccount(
                userName: randomEmail,
                password: randomPassword,
                loginRobot: ProtonCore_TestingToolkit.LoginRobot(),
                retRobot: MainRobot.self
            )
        
        correctUserIsLoggedIn(.init(username: randomEmail, password: randomPassword, plan: "Proton VPN Free"))
    }

    @MainActor
    func testSignInWithUsernameAccountWorks() async throws {
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        try await QuarkCommands.createAsync(account: .freeNoAddressNoKeys(username: randomUsername, password: randomPassword),
                                            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        _ = MainRobot()
            .showLogin()

        _ = SigninExternalAccountsCapability()
            .signInWithAccount(
                userName: randomUsername,
                password: randomPassword,
                loginRobot: ProtonCore_TestingToolkit.LoginRobot(),
                retRobot: MainRobot.self
            )

        correctUserIsLoggedIn(.init(username: randomUsername, password: randomPassword, plan: "Proton VPN Free"))
    }
    
//    Sign-up:
//    Sign-up with internal account works
//    Sign-up with external account works
//    The UI for sign-up with username account is not available

    @MainActor
    func testSignUpWithInternalAccountWorks() async throws {
        try await QuarkCommands.unbanAsync(currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        _ = MainRobot()
            .showSignup()

        SignupExternalAccountsCapability()
            .signUpWithInternalAccount(
                signupRobot: ProtonCore_TestingToolkit.SignupRobot().otherAccountButtonTap(),
                username: randomUsername,
                password: randomPassword,
                userEmail: randomEmail,
                verificationCode: "666666",
                retRobot: CreatingAccountRobot.self)
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown(time: signUpTimeout)

        _ = skipOnboarding()

        MainRobot()
            .goToSettingsTab()
            .verify.userIsCreated(randomUsername, "Proton VPN Free")

    }

    @MainActor
    func testSignUpWithExternalAccountWorks() async throws {
        try await QuarkCommands.unbanAsync(currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl())

        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)

        _ = MainRobot()
            .showSignup()

        SignupExternalAccountsCapability()
            .signUpWithExternalAccount(
                signupRobot: ProtonCore_TestingToolkit.SignupRobot(),
                userEmail: randomEmail,
                password: randomPassword,
                verificationCode: "666666",
                retRobot: CreatingAccountRobot.self
            )
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown(time: signUpTimeout)

        _ = skipOnboarding()

        MainRobot()
            .goToSettingsTab()
            .verify.userIsCreated(randomEmail, "Proton VPN Free")
    }

    @MainActor
    func testSignUpWithUsernameAccountIsNotAvailable() async throws {
        _ = MainRobot()
            .showSignup()

        ProtonCore_TestingToolkit.SignupRobot()
            .otherAccountButtonTap()
            .verify.domainsButtonIsShown()
    }
}

private let domainsButtonId = "SignupViewController.domainsButton"

extension ProtonCore_TestingToolkit.SignupRobot.Verify {
    @discardableResult
    func domainsButtonIsNotShown() -> ProtonCore_TestingToolkit.SignupRobot {
        button(domainsButtonId).checkDoesNotExist()
        return ProtonCore_TestingToolkit.SignupRobot()
    }
    
    @discardableResult
    func otherAccountExtButtonIsNotShown() -> ProtonCore_TestingToolkit.SignupRobot {
        button(CoreString._su_email_address_button).wait().checkDoesNotExist()
        return ProtonCore_TestingToolkit.SignupRobot()
    }
}

extension ProtonCore_TestingToolkit.RecoveryRobot {
    public func nextButtonTap<T: CoreElements>(robot: T.Type) -> T {
        _ = nextButtonTap()
        return T()
    }
}
