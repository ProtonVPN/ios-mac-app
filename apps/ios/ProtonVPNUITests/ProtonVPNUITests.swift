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
    var launchEnvironment: String?

    override func setUp() {
        super.setUp()
        app.launchArguments += ["UITests"]
        app.launchArguments += ["-BlockOneTimeAnnouncement", "YES"]
        app.launchArguments += ["-BlockUpdatePrompt", "YES"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        // Put setup code here. This method is called before the invocation of each test method in the class.

        setupSnapshot(app)
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Inject launchEnvironment
        if let env = launchEnvironment {
            app.launchEnvironment[env] = "1"
        }

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
    }

    // MARK: - Helper methods
    
    private let loginRobot = LoginRobot()
    private let onboardingRobot = OnboardingRobot()
    private let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)
    private let twopassusercredentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "twopassusercredentials", withExtension: "plist")!)
    
    func loginAsFreeUser() {
        login(withCredentials: credentials[0])
    }
    
    func loginAsBasicUser() {
        login(withCredentials: credentials[1])
    }
    
    func loginAsPlusUser() {
        login(withCredentials: credentials[2])
    }
    
    func loginAsTwoPassUser() {
        login(withCredentials: twopassusercredentials[0])
    }
    
    func login(withCredentials credentials: Credentials) {
        super.setUp()
        loginRobot
            .loginUser(credentials: credentials)
            .signIn(robot: LoginRobot.self)
        correctUserIsLogedIn(credentials)
    }
    
    @discardableResult
    func correctUserIsLogedIn(_ name: Credentials) -> MainRobot {
        app.buttons["Quick Connect"].waitForExistence(timeout: 15)
        app.tabBars.buttons["Settings"].tap()
        XCTAssert(app.staticTexts[name.username].exists)
        XCTAssert(app.staticTexts[name.plan].exists)
        return MainRobot()
    }
 
     func openLoginScreen() {
         let apiUrl = app.buttons["Use and continue"]
         apiUrl.tap()
         app.buttons["Sign in"].tap()
    }
    
    func useAndContinueTap() {
        app.buttons["Use and continue"].tap()
    }
    
    func logInToProdIfNeeded() {
        let tabBarsQuery = app.tabBars
        if !tabBarsQuery.allElementsBoundByIndex.isEmpty {
            return
        } else {
            changeEnvToProdIfNeeded()
            openLoginScreen()
            loginAsPlusUser()
        }
    }
    
    func logoutIfNeeded() {
        let tabBarsQuery = app.tabBars
        guard !tabBarsQuery.allElementsBoundByIndex.isEmpty else {
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
    
    func changeEnvToBlackIfNeeded() {
        let env = app.staticTexts[ObfuscatedConstants.blackDefaultHost + ObfuscatedConstants.blackDefaultPath]
        
        if env.waitForExistence(timeout: 10) {
            return
        } else {
            changeEnvToBlack()
            app.launch()
        }
    }
    
    func changeEnvToProdIfNeeded() {
        let env = app.staticTexts["https://vpn-api.proton.me"]
        
        if env.waitForExistence(timeout: 10) {
            return
        } else {
            changeEnvToProduction()
            app.launch()
        }
    }
    
    func skipOnboarding() -> OnboardingRobot {
        
        onboardingRobot.skipOnboarding()
        let elementClose = app.buttons["CloseButton"]
        
        if elementClose.exists {
            return onboardingRobot
                .closeOnboardingScreen()
                .skipOnboarding()
                .startUsingProtonVpn()
        } else {
            return onboardingRobot
                .nextOnboardingStep()
                .skipOnboarding()
                .startUsingProtonVpn()
                .closeOnboardingScreen()
        }
        return OnboardingRobot()
    }
}
