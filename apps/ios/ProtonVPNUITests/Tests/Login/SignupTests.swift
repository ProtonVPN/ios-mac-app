//
//  NewSignupTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest
import ProtonCore_Doh
import ProtonCore_QuarkCommands
import ProtonCore_TestingToolkit

class SignupTests: ProtonVPNUITests {
    
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
    private let signupRobot = SignupRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        // This method is asynchronous, but it still works, because it's enough time before the actual UI testing starts
        quarkCommands.unban { result in
            print("Unban finished: \(result)")
        }
     }
    
    func testSignupExistingIntAccount() {
        
        let email = "vpnfree"
        
        changeEnvToBlackIfNedded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: SignupRobot.self)
            .verify.usernameErrorIsShown()
    }
    
    func testSignupNewIntAccountSuccess() {
       
        let email = StringUtils().randomAlphanumericString(length: 5)
        let randomEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"
        let plan = "ProtonVPN Free"

        
        changeEnvToBlackIfNedded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .enterPassword(password)
            .enterRepeatPassword(password)
            .nextButtonTap(robot: ProtonCore_TestingToolkit.RecoveryRobot.self)
            .verify.recoveryScreenIsShown()
            .skipButtonTap()
            .verify.recoveryDialogDisplay()
            .skipButtonTap(robot: PaymentsRobot.self)
            .selectFreePlan()
            .verify.humanVerificationScreenIsShown()
            .performEmailVerification(email: randomEmail, code: code, to: AccountSummaryRobot.self)
            .accountSummaryElementsDisplayed(robot: SummarySignupRobot.self)
            .verify.summaryScreenIsShown()
            .startUsingProtonVpn()
            .goToSettingsTab()
            .verify.userIsCreated(email, plan)
    }
    
    func testSignupNewIntAccountWithRecoveryEmailSuccess() {
       
        let email = StringUtils().randomAlphanumericString(length: 5)
        let testEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let randomEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"
        let plan = "ProtonVPN Free"

        
        changeEnvToBlackIfNedded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .enterPassword(password)
            .enterRepeatPassword(password)
            .nextButtonTap(robot: RecoveryRobot.self)
            .insertRecoveryEmail(testEmail)
            .nextButtonTap(robot: PaymentsRobot.self)
            .selectFreePlan()
            .verify.humanVerificationScreenIsShown()
            .performEmailVerification(email: randomEmail, code: code, to: AccountSummaryRobot.self)
            .accountSummaryElementsDisplayed(robot: SummarySignupRobot.self)
            .verify.summaryScreenIsShown()
            .startUsingProtonVpn()
            .goToSettingsTab()
            .verify.userIsCreated(email, plan)
    }
    
    func testSignupNewExtAccountSuccess() {
        let email = StringUtils().randomAlphanumericString(length: 7) + "@mail.com"
        let code = "666666"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let plan = "ProtonVPN Free"
    
        changeEnvToBlackIfNedded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: AccountVerificationRobot.self)
            .verify.accountVerificationScreenIsShown()
            .enterVerificationCode(code)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .enterPassword(password)
            .enterRepeatPassword(password)
            .nextButtonTap(robot: PaymentsRobot.self)
            .verify.subscribtionScreenIsShown()
            .selectFreePlan()
    }
    
    func testSignupExistingExtAccount() {

        let email = "vpnfree@gmail.com"
        let code = "666666"
        
        changeEnvToBlackIfNedded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: AccountVerificationRobot.self)
            .verify.accountVerificationScreenIsShown()
            .enterVerificationCode(code)
            .nextButtonTap(robot: LoginRobot.self)
            .verify.emailAddresAlreadyExists()
            .verify.loginScreenIsShown()
    }
}
