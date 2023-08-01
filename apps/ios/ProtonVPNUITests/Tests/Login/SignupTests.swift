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
    lazy var environment: Environment = {
        guard let host = dynamicHost else {
            return .black
        }

        return .custom(host)
    }()
    
    lazy var quarkCommands = QuarkCommands(doh: environment.doh)
    private let mainRobot = MainRobot()
    private let signupRobot = SignupRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        // This method is asynchronous, but it still works, because it's enough time before the actual UI testing starts
        quarkCommands.unban { result in
            print("Unban finished: \(result)") // swiftlint:disable:this no_print
        }
     }

    /// Test showing standard plan (not Black Friday 2022 plan) for upgrade after successful signup
    @MainActor
    func testSignupNewExternalAccountSuccess() {
        let email = StringUtils().randomAlphanumericString(length: 7) + "@mail.com"
        let code = "666666"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let plan = "Proton VPN Free"
    
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()

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
            .skipOnboarding()
            .nextOnboardingStep()
            .nextOnboardingStep()
            .skipOnboarding()
            .startUsingProtonVpn()
            .startUpgrade()
            .verifyStaticText("Get Plus")
            .sleepFor(3)
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "VPN Plus")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "for 1 year")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "$99.99")
    }

    @MainActor
    func testSignupExistingExternalAccount() async {

        let email = "vpnfree@gmail.com"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"

        try? await QuarkCommands.createAsync(
            account: .external(email: email, password: password),
            currentlyUsedHostUrl: environment.doh.getCurrentlyUsedHostUrl()
        )

        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()

        ProtonCoreTestingToolkitUITestsLogin.SignupRobot()
            .insertExternalEmail(name: email)
            .nextButtonTapToOwnershipHV()
            .fillInTextField(code)
            .tapOnVerifyCodeButton(to: LoginRobot.self)
            .verify.emailAddressAlreadyExists()
            .verify.loginScreenIsShown()
    }
}
