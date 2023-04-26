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

import fusion
import XCTest

class ProtonVPNUITests: CoreTestCase {

    let app = XCUIApplication()
    var launchEnvironment: String?

    override func setUp() {
        super.setUp()
        app.launchArguments += ["UITests"]
        app.launchArguments += ["-BlockOneTimeAnnouncement", "YES"]
        app.launchArguments += ["-BlockUpdatePrompt", "YES"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        // Put setup code here. This method is called before the invocation of each test method in the class.
        app.launchArguments += ["enforceUnauthSessionStrictVerificationOnBackend"]

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

    let dynamicDomain: String = {
        if let domain = ProcessInfo.processInfo.environment["DYNAMIC_DOMAIN"], !domain.isEmpty {
            return "https://" + domain + "/api"
        } else {
            return ObfuscatedConstants.blackDefaultHost + ObfuscatedConstants.blackDefaultPath
        }
    }()

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
        correctUserIsLoggedIn(credentials)
    }
    
    @discardableResult
    func correctUserIsLoggedIn(_ name: Credentials) -> MainRobot {
        if app.buttons["Not Now"].waitForExistence(timeout: 60) { // keychain sheet
            app.buttons["Not Now"].tap()
        }
        guard app.buttons["Quick Connect"].waitForExistence(timeout: 5) else {
            XCTFail("Quick connect button never appeared.")
            return MainRobot()
        }
        if app.buttons["Settings"].waitForExistence(timeout: 1) {
            app.tabBars.buttons["Settings"].tap()
            staticText(name.plan).checkExists()
            staticText(name.username).checkExists()
        } else {
            XCTFail("Settings button never appeared")
        }
        return MainRobot()
    }
 
     func openLoginScreen() {
         useAndContinueTap()
         button("Sign in").tap()
    }
    
    func useAndContinueTap() {
        button("Use and continue").tap()
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
        _ = tabBarsQuery.element.waitForExistence(timeout: 1) // tests would reach this point when the tabbar is not yet available
        guard !tabBarsQuery.allElementsBoundByIndex.isEmpty else {
            return
        }
        
        tabBarsQuery.buttons["Settings"].tap()
        let logoutButton = app.buttons["Sign out"]
        app.swipeUp() // For iphone SE small screen
        logoutButton.tap()
    }
    
    func changeEnvToBlack() {
        textField("customEnvironmentTextField").waitForHittable().tap().clearText().typeText(dynamicDomain)

        button("Change and kill the app").tap()
        button("OK").tap()
     }
    
    func changeEnvToProduction() {
        button("Reset to production and kill the app").tap()
        button("OK").tap()
     }
    
    func changeEnvToBlackIfNeeded() {
        if staticText(dynamicDomain).wait().exists() {
            return
        } else {
            changeEnvToBlack()
            device().foregroundApp(.launch)
        }
    }
    
    func changeEnvToProdIfNeeded() {
        if staticText("https://vpn-api.proton.me").wait().exists() {
            return
        } else {
            changeEnvToProduction()
            device().foregroundApp(.launch)
        }
    }
    
    func skipOnboarding() -> OnboardingRobot {
        
        onboardingRobot.skipOnboarding()

        if button("CloseButton").exists() {
            return onboardingRobot
                .closeOnboardingScreen()
                .skipOnboarding()
                .startUsingProtonVpn()
        } else {

            return onboardingRobot
                .nextOnboardingStep()
                .nextOnboardingStep()
                .skipOnboarding()
                .startUsingProtonVpn()
                .closeOnboardingScreen()
        }
    }
}
