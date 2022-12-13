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
import pmtest
import ProtonCore_TestingToolkit
import ProtonCore_QuarkCommands
import ProtonCore_CoreTranslation
import ProtonCore_Environment

final class ExternalAccountsCapabilityATests: ProtonVPNUITests {
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
    }
    
//    Sign-in:
//    Sign-in with internal account works
//    Sign-in with external account works
//    Sign-in with username account works (no conversion to internal, so no address or keys generation)

    func testSignInWithInternalAccountWorks() {
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: .freeWithAddressAndKeys(username: randomUsername, password: randomPassword),
                             currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            expectQuarkCommandToFinish.fulfill()
        }
        
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("Internal account creation failed in test \(#function) because of \(error.userFacingMessageInQuarkCommands)")
            return
        }
        
        _ = MainRobot()
            .showLogin()
        
        _ = ProtonCore_TestingToolkit.LoginRobot()
            .fillUsername(username: randomUsername)
            .fillpassword(password: randomPassword)
            .signIn(robot: MainRobot.self)
        
        correctUserIsLogedIn(.init(username: randomUsername, password: randomPassword, plan: "Proton VPN Free"))
    }
    
    func testSignInWithExternalAccountWorks() {
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: .external(email: randomEmail, password: randomPassword),
                             currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            expectQuarkCommandToFinish.fulfill()
        }
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("External account creation failed in test \(#function) because of \(error.userFacingMessageInQuarkCommands)")
            return
        }
        
        _ = MainRobot()
            .showLogin()
        
        _ = ProtonCore_TestingToolkit.LoginRobot()
            .fillUsername(username: randomEmail)
            .fillpassword(password: randomPassword)
            .signIn(robot: MainRobot.self)
        
        correctUserIsLogedIn(.init(username: randomEmail, password: randomPassword, plan: "Proton VPN Free"))
    }
    
    func testSignInWithUsernameAccountWorks() {
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: .freeNoAddressNoKeys(username: randomUsername, password: randomPassword),
                             currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            expectQuarkCommandToFinish.fulfill()
        }
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("Username account creation failed in test \(#function) because of \(error.userFacingMessageInQuarkCommands)")
            return
        }

        _ = MainRobot()
            .showLogin()
        
        _ = ProtonCore_TestingToolkit.LoginRobot()
            .fillUsername(username: randomUsername)
            .fillpassword(password: randomPassword)
            .signIn(robot: MainRobot.self)
        
        correctUserIsLogedIn(.init(username: randomUsername, password: randomPassword, plan: "Proton VPN Free"))
    }
    
//    Sign-up:
//    The UI for sign-up with internal account is not available
//    The UI for sign-up with external account is not available
//    Sign-up with username account works
    
    func testSignUpWithInternalAccountIsNotAvailable() {
        _ = MainRobot()
            .showSignup()
        
        ProtonCore_TestingToolkit.SignupRobot()
            .verify.domainsButtonIsNotShown()
    }
    
    
    func testSignUpWithExternalAccountIsNotAvailable() {
        _ = MainRobot()
            .showSignup()
        
        ProtonCore_TestingToolkit.SignupRobot()
            .verify.otherAccountExtButtonIsNotShown()
    }
    
    func testSignUpWithUsernameAccountWorks() {
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        QuarkCommands.unban(currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { _ in
            expectQuarkCommandToFinish.fulfill()
        }
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        
        let randomUsername = StringUtils().randomAlphanumericString(length: 8)
        let randomPassword = StringUtils().randomAlphanumericString(length: 8)
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@proton.uitests"
        
        _ = MainRobot()
            .showSignup()
        
        let robot = ProtonCore_TestingToolkit.SignupRobot()
            .verify.domainsButtonIsNotShown()
            .verify.signupScreenIsShown()
            .insertName(name: randomUsername)
            .nextButtonTap(robot: ProtonCore_TestingToolkit.PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .insertPassword(password: randomPassword)
            .insertRepeatPassword(password: randomPassword)
            .nextButtonTap(robot: ProtonCore_TestingToolkit.RecoveryRobot.self)
            .verify.recoveryScreenIsShown()
            .insertRecoveryEmail(email: randomEmail)
            .nextButtonTap(robot: SignupHumanVerificationV3Robot.self)
            .verify.isHumanVerificationRequired()
            
        // workaround to have this test passing on the CI
        SignupHumanVerificationV3Robot().button(CoreString._hv_email_method_name).wait(time: 5.0)
        
        _ = robot
            .proceed(email: randomEmail, code: "666666", to: CreatingAccountRobot.self)
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown()
        _ = skipOnboarding()
        MainRobot()
            .goToSettingsTab()
            .verify.userIsCreated(randomUsername, "Proton VPN Free")
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
