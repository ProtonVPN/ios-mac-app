//
//  Created on 2022-01-11.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import XCTest
import Strings

fileprivate let qcButton = Localizable.quickConnect
fileprivate let disconnectButton = Localizable.disconnect
fileprivate let preferencesTitle = Localizable.preferences
fileprivate let menuItemReportAnIssue = Localizable.reportAnIssue
fileprivate let menuItemProfiles = Localizable.overview
fileprivate let statusTitle = Localizable.youAreNotConnected
fileprivate let initializingConnectionTitle = Localizable.initializingConnection
fileprivate let successfullyConnectedTitle = Localizable.successfullyConnected

class MainRobot {
    
    func openProfiles() -> ManageProfilesRobot {
        app.tabGroups[Localizable.profiles].forceClick()
        app.buttons[Localizable.createProfile].click()
        return ManageProfilesRobot()
    }
    
    func closeProfilesOverview() -> MainRobot {
        let preferencesWindow = app.windows[Localizable.profilesOverview]
        preferencesWindow.buttons[XCUIIdentifierCloseWindow].click()
        return MainRobot()
    }
    
    func openAppSettings() -> SettingsRobot {
        window.typeKey(",", modifierFlags: [.command]) // Settings…
        return SettingsRobot()
    }
    
    func quickConnectToAServer() -> MainRobot {
        app.buttons[qcButton].forceClick()
        return MainRobot()
    }
    
    func isConnected() -> Bool {
        return app.buttons[disconnectButton].waitForExistence(timeout: 5)
    }
    
    func disconnect() -> MainRobot {
        app.buttons[disconnectButton].forceClick()
        return MainRobot()
    }
    
    func logOut() -> LoginRobot {
        let logoutButton = app.menuBars.menuItems[Localizable.menuLogout]
        logoutButton.click()
        return LoginRobot()
    }
    
    func waitForConnecting(_ timeout: Int) -> Bool {
        return app.staticTexts[initializingConnectionTitle].waitForNonExistence(timeout: TimeInterval(timeout))
    }
    
    func isConnecting() -> Bool {
        return app.staticTexts[initializingConnectionTitle].exists
    }
    
    func cancelConnecting() -> MainRobot {
        app.buttons[Localizable.cancel].click()
        return MainRobot()
    }
    
    func isConnectionTimedOut() -> Bool {
        return app.staticTexts[Localizable.connectionTimedOut].exists
    }
    
    let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func checkSettingsModalIsClosed() -> SettingsRobot {
            XCTAssertFalse(app.buttons[preferencesTitle].exists)
            XCTAssertTrue(app.buttons[qcButton].exists)
            return SettingsRobot()
        }
        
        @discardableResult
        func checkUserIsLoggedIn() -> SettingsRobot {
            XCTAssert(app.staticTexts[statusTitle].waitForExistence(timeout: 10))
            XCTAssert(app.buttons[qcButton].waitForExistence(timeout: 10))
            return SettingsRobot()
        }
        
        @discardableResult
        func checkVPNConnecting() -> MainRobot {
            XCTAssert(app.staticTexts[initializingConnectionTitle].waitForExistence(timeout: 10), "\(initializingConnectionTitle) element not found.")
            return MainRobot()
        }
        
        @discardableResult
        func checkVPNConnected(with expectedProtocolName: String) -> MainRobot {
            // verify successfully connected label appears
            XCTAssert(app.staticTexts[successfullyConnectedTitle].waitForExistence(timeout: 10), "\(successfullyConnectedTitle) element not found.")
            
            // verify Disconnect button appears
            XCTAssert(app.buttons[Localizable.disconnect].waitForExistence(timeout: 10), "'\(Localizable.disconnect)' button not found.")
            
            // verify correct connected protocol appears
            let actualProtocol = app.staticTexts["protocolLabel"].value as! String
            XCTAssertEqual(expectedProtocolName, actualProtocol, "Invalid protol shown, expected: \(expectedProtocolName), actual: \(actualProtocol)")
            
            // verify IP Address label appears
            let actualIPAddress = app.staticTexts["ipLabel"].value as! String
            XCTAssertTrue(validateIPAddress(from: actualIPAddress), "IP label \(actualIPAddress) does not contain valid IP address")
            
            return MainRobot()
        }
        
        // MARK: private methods
        
        private func validateIPAddress(from string: String) -> Bool {
            let prefix = "IP: "
            guard string.hasPrefix(prefix) else {
                return false
            }
            
            let ipAddress = String(string.dropFirst(prefix.count))
            return ipAddress.isValidIPv4Address
        }
    }
}
