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
import PMLogger
import ProtonCoreDoh
import ProtonCoreEnvironment
import ProtonCoreLog
import ProtonCoreQuarkCommands
import ProtonCoreTestingToolkitUnitTestsCore
import ProtonCoreTestingToolkitUITestsCore
import XCTest

class ProtonVPNUITests: ProtonCoreBaseTestCase {

    let mainRobot = MainRobot()

    private static var isAutoFillPasswordsEnabled = true
    lazy var logFileUrl = LogFileManagerImplementation().getFileUrl(named: "ProtonVPN.log")

    /// Runs only once per test run.
    override class func setUp() {
        super.setUp()
        disableAutoFillPasswords()
    }

    override func setUp() {
       launchArguments = [
            "UITests",
            "-BlockOneTimeAnnouncement", "YES",
            "-BlockUpdatePrompt", "YES",
            "-AppleLanguages", "(en)",
            "enforceUnauthSessionStrictVerificationOnBackend",
            LogFileManagerImplementation.logDirLaunchArgument, logFileUrl.absoluteString
       ]

        beforeSetUp(bundleIdentifier: "ch.protonmail.vpn.ProtonVPNUITests", launchArguments: launchArguments)
        super.setUp()
        PMLog.info("UI TEST runs on: " + doh.getAccountHost())

        logoutIfNeeded()
    }


    func logoutIfNeeded() {
        let tabBarsQuery = app.tabBars
        _ = tabBarsQuery.element.waitForExistence(timeout: 5) // tests would reach this point when the tabbar is not yet available
        guard !tabBarsQuery.allElementsBoundByIndex.isEmpty else {
            return
        }

        tabBarsQuery.buttons["Settings"].tap()
        let logoutButton = app.buttons["Sign out"]
        app.swipeUp() // For iphone SE small screen
        logoutButton.tap()
    }

    override open func tearDownWithError() throws {
        if let logData = try? Data(contentsOf: logFileUrl),
           let logString = String(data: logData, encoding: .utf8) {
            let attachment = XCTAttachment(string: logString)
            attachment.name = "ProtonVPN.log"
            attachment.lifetime = .deleteOnSuccess
            add(attachment)
        }
        try super.tearDownWithError()
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

        var settingsText = "AutoFill Passwords"
        if #available(iOS 17.0, *) {
            settingsText = "AutoFill Passwords and Passkeys"
        }
        let autofillSwitch = settingsApp.switches[settingsText]
        if (autofillSwitch.value as? String) == "1" {
            autofillSwitch.tap()
        }
        isAutoFillPasswordsEnabled = false
    }

    func setupAtlasEnvironment() {
        let url = doh.getCurrentlyUsedHostUrl()
        if staticText(url).exists() {
            openLoginScreen()
        } else {
            textField("customEnvironmentTextField").waitUntilExists(time:1).tap().clearText().typeText(url)
            button("Change and kill the app").tap()
            closeAndOpenTheApp()
        }
    }

    func setupProdEnvironment() {
        if staticText("https://vpn-api.proton.me").waitUntilExists(time:1).exists() {
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

    lazy var quarkCommands = Quark().baseUrl(doh)

    var doh: DoH {
        if let customDomain = dynamicDomain.map({ "\($0)" }) {
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
