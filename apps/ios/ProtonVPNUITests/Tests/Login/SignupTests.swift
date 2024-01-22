//
//  NewSignupTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import ProtonCoreQuarkCommands
import ProtonCoreTestingToolkitUITestsLogin

class SignupTests: ProtonVPNUITests {

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
    }

    /// Test showing standard plan (not Black Friday 2022 plan) for upgrade after successful signup
    func testSignupNewExternalAccountUpgrade() throws  {
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

    func testSignupExistingExternalAccount() throws {
        let randomEmail = "\(StringUtils().randomAlphanumericString(length: 8))@gmail.com"
        let randomName = "\(StringUtils().randomAlphanumericString(length: 8))"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"
        let user = User(email: randomEmail, name: randomName, password: password, isExternal: true)

        try quarkCommands.userCreate(user: user)

        ProtonCoreTestingToolkitUITestsLogin.SignupRobot()
            .insertExternalEmail(name: randomEmail)
            .nextButtonTapToOwnershipHV()
            .fillInTextField(code)
            .tapOnVerifyCodeButton(to: LoginRobot.self)
            .verify.emailAddressAlreadyExists()
            .verify.loginScreenIsShown()
    }
}
