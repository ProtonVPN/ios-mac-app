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
import PMLogger
import Strings

class ProtonVPNUITests: XCTestCase {

    let app = XCUIApplication()
    var testCaseStart = Date()

    lazy var logFileUrl = LogFileManagerImplementation().getFileUrl(named: "ProtonVPN.log")

    override func setUp() {
        super.setUp()
        testCaseStart = Date()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app.launchArguments += ["-BlockOneTimeAnnouncement", "YES"]
        app.launchArguments += ["-BlockUpdatePrompt", "YES"]
        app.launchArguments += [LogFileManagerImplementation.logDirLaunchArgument,
                                logFileUrl.absoluteString]

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launch()

        window = XCUIApplication().windows["Proton VPN"]
        waitForLoaderDisappear()
        
    }

    override open func tearDownWithError() throws {
        try super.tearDownWithError()

        if FileManager.default.fileExists(atPath: logFileUrl.absoluteString) {
            let pmLogAttachment = XCTAttachment(contentsOfFile: logFileUrl)
            pmLogAttachment.lifetime = .deleteOnSuccess
            add(pmLogAttachment)
        }

        let group = DispatchGroup()
        group.enter()

        guard #available(macOS 12, *) else { return }

        let osLogContent = OSLogContent(scope: .system, since: testCaseStart)
        osLogContent.loadContent { [weak self] logContent in
            defer { group.leave() }

            guard let data = logContent.data(using: .utf8) as? NSData,
                  let compressed = try? data.compressed(using: .lz4) else {
                return
            }

            let osLogAttachment = XCTAttachment(data: compressed as Data)
            osLogAttachment.lifetime = .deleteOnSuccess
            osLogAttachment.name = "os_log_\(self?.name ?? "(nil)").txt.lz4"
            self?.add(osLogAttachment)
        }

        group.wait()
    }

    // MARK: - Helper methods
    
    private let loginRobot = LoginRobot()
    private let mainRobot = MainRobot()
    
    lazy var credentials = self.getCredentials(fromResource: "credentials")
    lazy var twopassusercredentials = self.getCredentials(fromResource: "twopassusercredentials")
    

    func getCredentials(fromResource resource: String) -> [Credentials] {
        return Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: resource, withExtension: "plist")!)
    }

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
    
    func waitForLoaderDisappear() {
        let loadingScreen = app.staticTexts[Localizable.loadingScreenSlogan]
        _ = loadingScreen.waitForExistence(timeout: 2)
        if !loadingScreen.waitForNonExistence(timeout: 10) {
            XCTFail("Loading screen does not disappear after 10 seconds")
        }
    }

    func login(withCredentials credentials: Credentials) {
        
        loginRobot
            .loginUser(credentials: credentials)
        
        waitForLoaderDisappear()
        mainRobot
            .verify
            .checkVPNDisconnected()
    }
    
    func verifyLoggedInUser(withCredentials credentials: Credentials) {
        let plan = credentials.plan.replacingOccurrences(of: "ProtonVPN", with: "Proton VPN")
        
        mainRobot
            .openAppSettings()
            .verify.checkSettingsIsOpen()
            .accountTabClick()
            .verify.checkAccountTabIsOpen()
            .verify.checkAccountTabUserName(username: credentials.username)
            .verify.checkAccountTabPlan(planName: plan)
            .closeSettings()
    }
    
    func logoutIfNeeded() {
        defer {
            if !app.buttons[Localizable.logIn].waitForExistence(timeout: 5) {
                XCTFail("Failed to log out. Login screen does not appear")
            }
        }
        _ = mainRobot
            .logOut()

        // give the main window time to load and show OpenVPN alert if needed
        sleep(2)

        dismissPopups()
        dismissDialogs()
    }

    func tryLoggingOut() -> Bool {
        let logoutButton = app.menuBars.menuItems["Sign out"]
        guard logoutButton.exists, logoutButton.isEnabled else {
            return false
        }
        logoutButton.click()
        return true
    }
    
    func logInIfNeeded() {
        let buttonQuickConnect = app.buttons["Quick Connect"]
        if buttonQuickConnect.waitForExistence(timeout: 4) {
            return
        } else {
            loginRobot
                .loginUser(credentials: credentials[2])
            
            waitForLoaderDisappear()
                         
            expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: buttonQuickConnect, handler: nil)
            waitForExpectations(timeout: 10, handler: nil)
                 
            dismissDialogs()
            dismissPopups()
        }
    }
    
    // to remove created profiles
    func clearAppData()  -> Bool {
        let clearAppDataButton = app.menuBars.menuItems["Clear Application Data"]
        let deleteButton = app.buttons["Delete"]
        guard clearAppDataButton.exists, clearAppDataButton.isEnabled else {
            return false
        }
        clearAppDataButton.click()
        deleteButton.click()
        return true
    }
    
    func waitForElementToAppear(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate,
                                                    object: element)

        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        return result == .completed
    }
    
    func dismissPopups() {
        let dismissButtons = ["Cancel", "No thanks", "Take a Tour", "Got it!"]
        
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
