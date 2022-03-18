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

import pmtest
import XCTest

class ProtonVPNUITests: XCTestCase {

    let app = XCUIApplication()
    
    override func setUp() {
        app.launchArguments = ["UITests"]
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
    
    private let loginRobot = LoginRobot()
    private let onboardingRobot = OnboardingRobot()
    private let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)
    
    func loginAsFreeUser() {
        login(withCredentials: credentials[0])
    }
    
    func loginAsBasicUser() {
        login(withCredentials: credentials[1])
    }
    
    func loginAsPlusUser() {
        login(withCredentials: credentials[2])
    }
    
    func loginAsVisionaryUser() {
        login(withCredentials: credentials[3])
    }
    
    func login(withCredentials credentials: Credentials) {
        let buttonQuickConnect = app.buttons["Quick Connect"]
        super.setUp()
        loginRobot
            .loginUser(credentials: credentials)
        
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: buttonQuickConnect, handler: nil)
                waitForExpectations(timeout: 10, handler: nil)

        app.tabBars.buttons["Settings"].tap()
        XCTAssert(app.staticTexts[credentials.username].exists)
        XCTAssert(app.staticTexts[credentials.plan].exists)

        switch credentials.plan {
        case "Proton VPN Basic", "Proton VPN Plus", "Proton Visionary":
            XCTAssert(app.buttons["Manage subscription"].exists)
        default:
            XCTAssertFalse(app.buttons["Manage subscription"].exists)
        }
    }
 
     func openLoginScreen(){
         let apiUrl = app.buttons["Use and continue"]
         apiUrl.tap()
         app.buttons["Sign in"].tap()
    }
    
    func useAndContinueTap() {
        app.buttons["Use and continue"].tap()
    }
    
    func logInToProdIfNeeded() {
        let tabBarsQuery = app.tabBars
        if tabBarsQuery.allElementsBoundByIndex.count > 0  {
            return
        }
        else {
            changeEnvToProdIfNedded()
            openLoginScreen()
            loginAsPlusUser()
        }
    }
    
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
    
    func changeEnvToBlack() {
        let textFielfs = app.textFields["https://"]
        textFielfs.tap()
        textFielfs.typeText(ObfuscatedConstants.blackDefaultHostWithoutHttps + ObfuscatedConstants.blackDefaultPath)
        app.buttons["Change and kill the app"].tap()
        app.buttons["OK"].tap()
     }
    
    func changeEnvToProduction() {
        let resetToProd = app.buttons["Reset to production and kill the app"]
        resetToProd.tap()
        app.buttons["OK"].tap()
     }
    
    func changeEnvToBlackIfNedded() {
        let env = app.staticTexts[ObfuscatedConstants.blackDefaultHost + ObfuscatedConstants.blackDefaultPath]
        
        if env.waitForExistence(timeout: 4){
            return
        }
        else {
            changeEnvToBlack()
            app.launch()
        }
    }
    
    func changeEnvToProdIfNedded() {
        let env = app.staticTexts["https://api.protonvpn.ch"]
        
        if env.waitForExistence(timeout: 4){
            return
        }
        else {
            changeEnvToProduction()
            app.launch()
        }
    }
    
    func skipOnboarding() -> OnboardingRobot {
        
        onboardingRobot.skipOnboarding()
        let elementclose = app.buttons["CloseButton"]
        
        if elementclose.exists {
            return onboardingRobot.closeOnboardingScreen().skipOnboarding().startUsingProtonVpn()
        }
        else {
          return onboardingRobot.skipOnboarding().startUsingProtonVpn().closeOnboardingScreen()
        }
        return OnboardingRobot()
    }
}
