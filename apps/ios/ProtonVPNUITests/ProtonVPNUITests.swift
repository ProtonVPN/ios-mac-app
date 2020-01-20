//
//  ProtonVPNUITests.swift
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

class ProtonVPNUITests: XCTestCase {

    let app = XCUIApplication()
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        setupSnapshot(app)
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Helper methods
    
    func logoutIfNeeded() {
        let tabBarsQuery = app.tabBars
        guard tabBarsQuery.allElementsBoundByIndex.count > 0 else {
            return
        }
        
        tabBarsQuery.buttons["Settings"].tap()
        
        let logoutButton = app.buttons["Log Out"]
        app.swipeUp() // For iphone SE small screen
        logoutButton.tap()
    }
    
    func assertLastWizardScreen(){
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.buttons["Log In"], handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
        
        XCTAssert(app.buttons["Log In"].exists)
        XCTAssert(app.buttons["Sign Up"].exists)
    }
    
    func assertLoginScreenOpen() {
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.textFields["Username"], handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.secureTextFields["Password"], handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
                
        if app.buttons["Agree & Continue"].exists {
            app.buttons["Agree & Continue"].tap()
        }
        
        XCTAssert(app.textFields["Username"].exists)
        XCTAssert(app.secureTextFields["Password"].exists)
    }
    
    func assertRegistrationScreenOpen() {
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.textFields["Enter email address"], handler: nil)
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.buttons["Get verification email"], handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
        
        if app.buttons["Agree & Continue"].exists {
            app.buttons["Agree & Continue"].tap()
        }
        
        XCTAssert(app.textFields["Enter email address"].exists)
        XCTAssert(app.buttons["Get verification email"].exists)
    }
        
}
