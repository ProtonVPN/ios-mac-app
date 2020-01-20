//
//  LoginTests.swift
//  ProtonVPN - Created on 27.06.19.
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

import Foundation
import XCTest

class LoginTests: ProtonVPNUITests {
    
    var loginButton: XCUIElement!
    var fieldUsername: XCUIElement!
    var fieldPassword: XCUIElement!
    var errorMessage: XCUIElement!
    
    override func setUp() {
        super.setUp()
    
        loginButton = window.buttons["Login"]
        fieldUsername = window.textFields["Username"]
        fieldPassword = window.secureTextFields["Password"]
        errorMessage = app.staticTexts["Wrong username or password"]
        
        logoutIfNeeded()
    }
    
    func testLoginWithIncorrectCredentials_C140() {
        
        // With empty fields
        XCTAssertFalse(loginButton.isEnabled)
        
        // With empty username
        fieldPassword.click()
        fieldPassword.typeText("test")
        XCTAssertFalse(loginButton.isEnabled)
        
        // With empty password
        fieldUsername.clearAndEnterText(text: "text")
        fieldPassword.clearAndEnterText(text: "")
        XCTAssertFalse(loginButton.isEnabled)
        
        // With incorrect credentials
        fieldUsername.clearAndEnterText(text: "zxcvbnm")
        fieldPassword.clearAndEnterText(text: "asdfghj")
        XCTAssert(loginButton.isEnabled)
        loginButton.click()
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: errorMessage, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testLoginWithIncorrectUnicodeCredentials_C140() {
        // With unicode symbols
        fieldUsername.clearAndEnterText(text: "ąčęėįš")
        fieldPassword.clearAndEnterText(text: "žūųšįė")
        XCTAssert(loginButton.isEnabled)
        loginButton.click()
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts["Invalid username"], handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testLoginWithCorrectCredentials_C139() {
        let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)
        
        for credential in credentials {
            login(withCredentials: credential)
            logoutIfNeeded()
            app.terminate()
            app.launch()
        }
        
    }
    
    private func login(withCredentials credentials: Credentials) {
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: loginButton, handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: fieldUsername, handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: fieldPassword, handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
        
        fieldUsername.clearAndEnterText(text: credentials.username)
        fieldPassword.clearAndEnterText(text: credentials.password)
        loginButton.click()
        
        _ = waitForElementToDisappear(app.otherElements["loader"])
        
        let buttonQuickConnect = app.buttons["Quick Connect"]
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: buttonQuickConnect, handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
        
        dismissUpgradePopup()
        
        window.typeKey(",", modifierFlags:.command)

        let preferencesWindow = app.windows["Preferences"]
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: preferencesWindow.buttons["Account"], handler: nil)
        expectation(for: NSPredicate(format: "exists == isHittable"), evaluatedWith: preferencesWindow.buttons["Account"], handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
        preferencesWindow.buttons["Account"].click()

        XCTAssert(app.staticTexts[credentials.username].exists)
        XCTAssert(app.staticTexts[credentials.plan].exists)

        preferencesWindow.buttons[XCUIIdentifierCloseWindow].click()
    }
    
}
