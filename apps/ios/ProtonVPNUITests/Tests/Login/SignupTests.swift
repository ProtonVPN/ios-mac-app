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

fileprivate let verificationCode = "666666"

class SignupTests: ProtonVPNUITests {

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
    }

    /// Test showing standard plan (not Black Friday 2022 plan) for upgrade after successful signup
    func testSignUpWithExternalAccount() throws  {
        let randomData = getRandomData(emailPostfix: "mail.com")
        let randomEmail = randomData.email
        let randomPassword = randomData.password

        SignupExternalAccountsCapability()
            .signUpWithExternalAccount(
                signupRobot: ProtonCoreTestingToolkitUITestsLogin.SignupRobot(),
                userEmail: randomEmail,
                password: randomPassword,
                verificationCode: verificationCode,
                retRobot: CreatingAccountRobot.self
            )

        verifyOnboardingScreen(for: randomEmail)
    }

    func testSignUpWithInternalAccount() {
        let randomData = getRandomData(emailPostfix: "proton.uitests")
        let randomEmail = randomData.email
        let randomUsername = randomData.userName
        let randomPassword = randomData.password

        SignupExternalAccountsCapability()
            .signUpWithInternalAccount(
                signupRobot: ProtonCoreTestingToolkitUITestsLogin.SignupRobot().otherAccountButtonTap(),
                username: randomUsername,
                password: randomPassword,
                userEmail: randomEmail,
                verificationCode: verificationCode,
                retRobot: CreatingAccountRobot.self)

        verifyOnboardingScreen(for: randomUsername)
    }

    func testSignUpWithExistingExternalAccount() throws {
        let randomData = getRandomData(emailPostfix: "mail.com")
        let randomEmail = randomData.email
        let randomName = randomData.userName
        let randomPassword = randomData.password

        let existingUser = User(email: randomEmail, name: randomName, password: randomPassword, isExternal: true)

        try quarkCommands.userCreate(user: existingUser)

        ProtonCoreTestingToolkitUITestsLogin.SignupRobot()
            .insertExternalEmail(name: randomEmail)
            .nextButtonTapToOwnershipHV()
            .fillInTextField(verificationCode)
            .tapOnVerifyCodeButton(to: LoginRobot.self)
            .verify.emailAddressAlreadyExists()
            .verify.loginScreenIsShown()
    }

    private func verifyOnboardingScreen(for userEmail: String) {
        CreatingAccountRobot()
            .verify.creatingAccountScreenIsShown()
            .verify.onboardingScreenIsShown()
            .tapUpgradePlan()
            .verify.subscriptionModalIsShown()
            .verify.verifyPlanOptions(planDuration: "1 month", planAmount: "$11.99")
            .verify.verifyPlanOptions(planDuration: "12 months", planAmount: "$79.99")
            .closeModal(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
            .verify.userIsCreated(userEmail, "Proton VPN Free")
    }

    private func getRandomData(emailPostfix: String) -> (email: String, userName: String, password: String) {
        // Generate random data using StringUtils.randomAlphanumericString
        let randomEmail = "\(StringUtils.randomAlphanumericString(length: 8).lowercased())@\(emailPostfix)"
        let randomName = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)

        return (email: randomEmail, userName: randomName, password: randomPassword)
    }
}
