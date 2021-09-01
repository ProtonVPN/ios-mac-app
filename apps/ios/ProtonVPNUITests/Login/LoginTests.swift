//
//  LoginTests.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import XCTest

class LoginTests: ProtonVPNUITests {
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        openLoginScreen()
    }
    
    func testLoginWithIncorrectCredentials_C100() {
        // FUTURETODO: read texts from translation file
        let fieldUsername = app.textFields["Username"]
        let fieldPassword = app.secureTextFields["Password"]
        let buttonLogin = app.buttons["login_button"]
        let errorMessage = app.otherElements["Error notification with code 8002"] // 8002 - wrong username or password
        
        XCTAssertFalse(buttonLogin.isEnabled)
        fieldUsername.tap()
        fieldUsername.typeText("wrong_user_jd233@dsd33jd.c0m")
        fieldPassword.tap()
        fieldPassword.typeText("wrong password")
        XCTAssert(buttonLogin.isEnabled)
        XCTAssert(buttonLogin.isHittable)
        buttonLogin.tap()
        
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: errorMessage, handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testLoginWithCorrectCredentials_C101() {
        let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)
        
        for credential in credentials {
            login(withCredentials: credential)
            logoutIfNeeded()
            openLoginScreen()
        }
    }
    
//    private func login(withCredentials credentials: Credentials) {
//        let fieldUsername = app.textFields["Username"]
//        let fieldPassword = app.secureTextFields["Password"]
//        let buttonLogin = app.buttons["login_button"]
//        let buttonQuickConnect = app.buttons["Quick Connect"]
//        
//        fieldUsername.tap()
//        fieldUsername.typeText(credentials.username)
//        fieldPassword.tap()
//        fieldPassword.typeText(credentials.password)
//        buttonLogin.tap()
//        
//        let trialButton = app.buttons["Maybe Later"]
//        if trialButton.waitForExistence(timeout: 5) {
//            trialButton.tap()
//        }
//        
//        let extensionsButton = app.buttons["Begin manual configuration"]
//        if extensionsButton.waitForExistence(timeout: 5) {
//            extensionsButton.tap()
//        }
//
//        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: buttonQuickConnect, handler: nil)
//        waitForExpectations(timeout: 10, handler: nil)
//
//        app.tabBars.buttons["Settings"].tap()
//
//        XCTAssert(app.staticTexts[credentials.username].exists)
//        XCTAssert(app.staticTexts[credentials.plan].exists)
//
//        switch credentials.plan {
//        case "ProtonVPN Basic", "ProtonVPN Plus":
//            XCTAssert(app.buttons["Manage subscription"].exists)
//        default:
//            XCTAssertFalse(app.buttons["Manage subscription"].exists)
//        }
//
//    }
    
    // MARK: - Helper methods
    
//    private func openLoginScreen(){
//        let skipButton = app.buttons["Skip"]
//        skipButton.tap()
//        assertLastWizardScreen()
//        app.buttons["Log In"].tap()
//        assertLoginScreenOpen()
//    }
    
}
