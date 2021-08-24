//
//  ProtonVPNUITests.swift
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

import XCTest

class ProtonVPNUITests: XCTestCase {

    let app = XCUIApplication()
    var window: XCUIElement!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launch()

        window = XCUIApplication().windows["ProtonVPN"]
        
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Helper methods
    
    func logoutIfNeeded() {
        _ = waitForElementToDisappear(app.otherElements["loader"])

        // give the main window time to load and show OpenVPN alert if needed
        sleep(2)
        
        dismissPopups()
        dismissDialogs()
        
        let logoutButton = app.menuBars.menuItems["Log Out"]
        guard logoutButton.exists, logoutButton.isEnabled else {
            return
        }
        
        window.typeKey("w", modifierFlags:[.command, .shift])
        
        // Make sure app is fully logged out
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.buttons["Login"], handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func waitForElementToDisappear(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate,
                                                    object: element)

        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        return result == .completed
    }
    
    func waitForElementToAppear(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate,
                                                    object: element)

        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        return result == .completed
    }
    
    func dismissPopups() {
        let dismissButtons = ["Maybe Later", "Cancel"]
        
        for button in dismissButtons {
            if app.buttons[button].exists {
                app.buttons[button].firstMatch.click()
                
                // repeat in case another alert is queued
                sleep(1)
                dismissPopups()
                return
            }
        }
    }
    
    func dismissDialogs() {
        let dialogs = ["Enabling custom protocols"]
        
        for dialog in dialogs {
            if app.dialogs[dialog].exists {
                app.dialogs[dialog].firstMatch.buttons["_XCUI:CloseWindow"].click()

                // repeat in case another alert is queued
                sleep(1)
                dismissDialogs()
                return
            }
        }
    }
    
}
