//
//  LoginExtAccountsTests.swift
//  ProtonVPNUITests
//
//  Created on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest
import pmtest
import ProtonCore_TestingToolkit

@available(iOS 15.0, *)
class LoginExtAccountTests: ProtonVPNUITests {

    let mainRobot = MainRobot()
    let loginRobot = ProtonCore_TestingToolkit.LoginRobot()
    
    override func setUp() {
        launchEnvironment = "ExtAccountNotSupportedStub"
        super.setUp()
        logoutIfNeeded()
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testLoginExtAcountNotSupported() {
        loginRobot
            .fillUsername(username: "ExtUser")
            .fillpassword(password: "123")
            .signIn(robot: LoginRobot.self)
            .verify.bannerExtAccountError()
    }
}

extension LoginRobot.Verify {
    func bannerExtAccountError() {
        textView("This app does not support external accounts").wait().checkExists()
    }
}
