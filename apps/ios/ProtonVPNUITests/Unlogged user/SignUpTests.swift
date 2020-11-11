//
//  SignUpTests.swift
//  ProtonVPN - Created on 2020-08-28.
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

class SignUpTests: ProtonVPNUITests {
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
    }
    
    private func goToPlanList() {
        let skipButton = app.buttons["Skip"]
        skipButton.tap()
        
        let signupButton = app.buttons["Sign Up"]
        signupButton.tap()
        
        let agreeButton = app.buttons["Agree & Continue"]
        if agreeButton.exists {
            agreeButton.tap()
        }
    }
    
    func testPlanListOpensOnSignInStart() {
        
        goToPlanList()
        snapshot("PlanSelection")
        
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts["ProtonVPN PLUS"], handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts["ProtonVPN BASIC"], handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts["ProtonVPN FREE"], handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        
    }

    func testEmailAutofillDoesntShowError() throws {
        goToPlanList()
        
        let fieldEmail = app.textFields["email"]
        let fieldUsername = app.textFields["username"]
        let fieldPassword1 = app.secureTextFields["pass1"]
        let fieldPassword2 = app.secureTextFields["pass2"]
        let button = app.buttons["mainButton"]

        let elementsQuery = app.scrollViews.otherElements
        elementsQuery.otherElements["free"].tap()
        elementsQuery.buttons["Select plan"].tap()
        
        XCTAssertFalse(button.isEnabled)
        fieldEmail.tap()
        fieldEmail.typeText("email@address.com ") // Autofill adds empty space
        fieldUsername.tap()
        fieldUsername.typeText("username")
        fieldPassword1.tap()
        fieldPassword1.typeText("123456")
        fieldPassword2.tap()
        fieldPassword2.typeText("123") // We don't want to proceed with signup
        
        XCTAssert(button.isEnabled)
        button.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["wrongEmail"], handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts["passwordsDontMatch"], handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
        
    }

}
