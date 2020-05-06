//
//  RegisterTests.swift
//  ProtonVPN - Created on 05/05/2020.
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

class RegisterTests: ProtonVPNUITests {

    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        openRegisterScreen()
    }
    
    func testRegisterWithExistingUser() {
        let email = app.textFields["email"]
        let username = app.textFields["username"]
        let pass1 = app.secureTextFields["pass1"]
        let pass2 = app.secureTextFields["pass2"]
        let mainButton = app.buttons["mainButton"]
        
        email.tap()
        email.typeText("mrk.flores@protonmail.com")
        username.tap()
        username.typeText("testas1")
        pass1.tap()
        pass1.typeText("testas1")
        pass2.tap()
        pass2.typeText("testas1")
        mainButton.tap()
        
        let errorMessage = app.otherElements["Error notification with code 12106"] // 8002 - wrong username or password
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: errorMessage, handler: nil)
        waitForExpectations(timeout: 2) { _ in
            
        }
    }
    
    // MARK: - Helper methods
    
    private func openRegisterScreen(){
        let skipButton = app.buttons["Skip"]
        skipButton.tap()
        assertLastWizardScreen()
        app.buttons["Sign Up"].tap()
        assertPlanSelectScreenOpen()
        app.otherElements["free"].tap()
        app.buttons["Select plan"].tap()
        assertRegistrationScreenOpen()
    }
}
