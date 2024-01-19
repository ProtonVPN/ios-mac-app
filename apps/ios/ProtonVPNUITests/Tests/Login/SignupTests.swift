//
//  NewSignupTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import ProtonCoreDoh
import ProtonCoreEnvironment
import ProtonCoreQuarkCommands
import ProtonCoreTestingToolkitUITestsLogin

class SignupTests: ProtonVPNUITests {

    private let mainRobot = MainRobot()
    private let signupRobot = SignupRobot()
    private let onboardingRobot = OnboardingRobot()

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()

        unbanBeforeSignup(doh: doh)
     }

    /// Test showing standard plan (not Black Friday 2022 plan) for upgrade after successful signup
    func testSignupNewExternalAccountUpgrade() {
        let email = StringUtils().randomAlphanumericString(length: 7) + "@mail.com"
        let code = "666666"
        let password = StringUtils().randomAlphanumericString(length: 8)

        SignupExternalAccountsCapability()
            .signUpWithExternalAccount(
                signupRobot: ProtonCoreTestingToolkitUITestsLogin.SignupRobot(),
                userEmail: email,
                password: password,
                verificationCode: code,
                retRobot: CreatingAccountRobot.self
            )
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown()
            .getStart()
            .upgradePlan()
            .verifyStaticText("Get Plus")
            .sleepFor(3)
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "VPN Plus")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "for 1 year")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "$99.99")
    }

    func testSignupExistingExternalAccount() {
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@gmail.com"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"

        guard createAccountForTest(doh: doh, accountToBeCreated: .external(email: randomEmail, password: password)) else { return }

        ProtonCoreTestingToolkitUITestsLogin.SignupRobot()
            .insertExternalEmail(name: randomEmail)
            .nextButtonTapToOwnershipHV()
            .fillInTextField(code)
            .tapOnVerifyCodeButton(to: LoginRobot.self)
            .verify.emailAddressAlreadyExists()
            .verify.loginScreenIsShown()
    }
}
