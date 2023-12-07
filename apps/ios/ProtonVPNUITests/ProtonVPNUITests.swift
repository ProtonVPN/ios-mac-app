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
import PMLogger
import ProtonCoreDoh

class ProtonVPNUITests: CoreTestCase {

    let app = XCUIApplication()
    var launchEnvironment: String?
    lazy var logFileUrl = LogFileManagerImplementation().getFileUrl(named: "ProtonVPN.log")
    
    private static var isAutoFillPasswordsEnabled = true
        
    /// Runs only once per test run.
    override class func setUp() {
        super.setUp()
        disableAutoFillPasswords()
    }
    
    /// Runs before each test case.
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        app.launchArguments += ["UITests"]
        app.launchArguments += ["-BlockOneTimeAnnouncement", "YES"]
        app.launchArguments += ["-BlockUpdatePrompt", "YES"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        // Put setup code here. This method is called before the invocation of each test method in the class.
        app.launchArguments += ["enforceUnauthSessionStrictVerificationOnBackend"]
        app.launchArguments += [LogFileManagerImplementation.logDirLaunchArgument,
                                logFileUrl.absoluteString]

        setupSnapshot(app)

        // Inject launchEnvironment
        if let env = launchEnvironment {
            app.launchEnvironment[env] = "1"
        }

        app.launch()
        
        logoutIfNeeded()

    }

    override open func tearDownWithError() throws {
        
        try super.tearDownWithError()
        
        if FileManager.default.fileExists(atPath: logFileUrl.absoluteString) {
            let pmLogAttachment = XCTAttachment(contentsOfFile: logFileUrl)
            pmLogAttachment.lifetime = .deleteOnSuccess
            add(pmLogAttachment)
        }

        guard #available(iOS 15, *) else { return }

        let group = DispatchGroup()
        group.enter()

        let osLogContent = OSLogContent()
        osLogContent.loadContent { [weak self] logContent in
            let osLogAttachment = XCTAttachment(string: logContent)
            osLogAttachment.lifetime = .deleteOnSuccess
            self?.add(osLogAttachment)

            group.leave()
        }

        group.wait()
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
    
    private static func disableAutoFillPasswords() {
        guard #available(iOS 16.0, *), isAutoFillPasswordsEnabled else {
            return
        }

        let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        settingsApp.launch()
        defer {
            settingsApp.terminate()
        }
        settingsApp.tables.staticTexts["PASSWORDS"].tap()

        let passcodeInput = springboard.secureTextFields["Passcode field"]
        passcodeInput.tap()
        passcodeInput.typeText("1\r")
        let cell = settingsApp.tables.cells["PasswordOptionsCell"]
        _ = cell.waitForExistence(timeout: 1)
        guard cell.exists else {
            return
        }
        cell.buttons["chevron"].tap()
        let autofillSwitch = settingsApp.switches["AutoFill Passwords"]
        if (autofillSwitch.value as? String) == "1" {
            autofillSwitch.tap()
        }
        isAutoFillPasswordsEnabled = false
    }

    func setupAtlasEnvironment() {
           if staticText(dynamicDomain).exists() {
               openLoginScreen()
           } else {
               textField("customEnvironmentTextField").wait(time:1).tap().clearText().typeText(dynamicDomain)
               button("Change and kill the app").tap()
               closeAndOpenTheApp()
           }
       }
           
    func setupProdEnvironment() {
           if staticText("https://vpn-api.proton.me").wait(time:1).exists() {
               openLoginScreen()
           } else {
               button("Reset to production and kill the app").tap()
               closeAndOpenTheApp()
           }
       }
       
    private func closeAndOpenTheApp() {
           button("OK").tap()
           device().foregroundApp(.launch)
           button("Use and continue").tap()
       }
       
    private func openLoginScreen() {
           button("Use and continue").tap()
       }

    let dynamicDomain: String = {
        if let domain = ProcessInfo.processInfo.environment["DYNAMIC_DOMAIN"], !domain.isEmpty {
            return "https://" + domain + "/api"
        } else {
            return ObfuscatedConstants.blackDefaultHost + ObfuscatedConstants.blackDefaultPath
        }
    }()

    lazy var dynamicHost: String? = {
        let url = URL(string: dynamicDomain) ??
            URL(string: ObfuscatedConstants.blackDefaultHost)!

        if #available(iOS 16, *) {
            if let host = url.host() {
                return host
            }
        } else {
            if let host = url.host {
                return host
            }
        }
        return nil
    }()
    
    var doh: DoHInterface {
        if let customDomain = ProcessInfo.processInfo.environment["DYNAMIC_DOMAIN"] {
            return CustomServerConfigDoH(
                signupDomain: customDomain,
                captchaHost: "https://api.\(customDomain)",
                humanVerificationV3Host: "https://verify.\(customDomain)",
                accountHost: "https://account.\(customDomain)",
                defaultHost: "https://\(customDomain)",
                apiHost: ObfuscatedConstants.blackApiHost,
                defaultPath: ObfuscatedConstants.blackDefaultPath
            )
        } else {
            return CustomServerConfigDoH(
                signupDomain: ObfuscatedConstants.blackSignupDomain,
                captchaHost: ObfuscatedConstants.blackCaptchaHost,
                humanVerificationV3Host: ObfuscatedConstants.blackHumanVerificationV3Host,
                accountHost: ObfuscatedConstants.blackAccountHost,
                defaultHost: ObfuscatedConstants.blackDefaultHost,
                apiHost: ObfuscatedConstants.blackApiHost,
                defaultPath: ObfuscatedConstants.blackDefaultPath
            )
        }
    }
}
