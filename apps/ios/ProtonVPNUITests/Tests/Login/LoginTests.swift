//
//  NewLoginTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import XCTest
import ProtonCoreTestingToolkitUITestsLogin

class LoginTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()
    
    private lazy var twopassusercredentials = getCredentials(from: "twopassusercredentials")

    override func setUp() {
        super.setUp()
        setupProdEnvironment() 
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    func testLoginWithIncorrectCredentials() {

        let username = twopassusercredentials[0].username
        let userpassword = "wrong_password"

        loginRobot
            .enterIncorrectCredentials(username, userpassword)
            .signIn(robot: LoginRobot.self)
            .verify.incorrectCredentialsErrorDialog()
    }
    
    func testLoginWithSpecialChars() {
        let username = "ąčęėįš"
        let password = "ąčęėįš"
        
        loginRobot
            .enterIncorrectCredentials(username, password)
            .signIn(robot: LoginRobot.self)
            .verify.specialCharErrorDialog()
    }

    func testLoginAsSubuserWithNoConnectionsAssigned() {

        let subusercredentials = getCredentials(from: "subusercredentials")

        loginRobot
            .enterCredentials(subusercredentials[0])
            .signIn(robot: LoginRobot.self)
            .verify.assignVPNConnectionErrorIsShown()
            .verify.loginScreenIsShown()
    }

    func testLoginWithTwoPassUser() {
        
        loginRobot
            .enterCredentials(twopassusercredentials[0])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
        loginRobot
            .verify.correctUserIsLogedIn(twopassusercredentials[0])
    }

    func testLoginAsTwoFa() {
        let twofausercredentials = getCredentials(from: "twofausercredentials")

        loginRobot
            .enterCredentials(twofausercredentials[0])
            .signIn(robot: TwoFaRobot.self)
            .fillTwoFACode(code: generateCodeFor2FAUser(ObfuscatedConstants.twoFASecurityKey))
            .confirm2FA(robot: MainRobot.self)
            .dismissWhatsNewModal()
            .goToSettingsTab()
        loginRobot
            .verify.correctUserIsLogedIn(twofausercredentials[0])
    }

    func testLoginWithTwoPassAnd2FAUser() {

        let twopasstwofausercredentials = getCredentials(from: "twopasstwofausercredentials")

        loginRobot
            .enterCredentials(twopasstwofausercredentials[0])
            .signIn(robot: TwoFaRobot.self)
            .fillTwoFACode(code: generateCodeFor2FAUser(ObfuscatedConstants.twoFAandTwoPassSecurityKey))
            .confirm2FA(robot: MainRobot.self)
            .dismissWhatsNewModal()
            .goToSettingsTab()
        loginRobot
            .verify.correctUserIsLogedIn(twopasstwofausercredentials[0])
    }
}
