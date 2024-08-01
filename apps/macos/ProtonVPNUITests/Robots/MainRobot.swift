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
        window.typeKey("w", modifierFlags: [.shift, .command])
        return LoginRobot()
    }
    
    func waitForConnectingFinish(_ timeout: Int) -> Bool {
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
    
    func searchForCountry(country: String) -> MainRobot {
        let countrySearchField = app.textFields["SearchTextField"]
        countrySearchField.click()
        countrySearchField.typeText(country)
        return MainRobot()
    }
    
    func connectToCountry(country: String) -> MainRobot {
        let cell = app.cells[country]
        // hovering over the cell with country in order to make "Connect" button visible
        // using dx: 0.7 as Connect button placed at the right part of the cell
        cell.forceHover(dx: 0.7, dy: 0.5)
        // Clicking cell with country by coordinates hoping that Connect button is there
        // using dx: 0.7 as Connect button placed at the right part of the cell
        cell.forceClick(dx: 0.7, dy: 0.5)
        return MainRobot()
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
        func checkConnectionCardIsConnected(with expectedProtocol: ConnectionProtocol,
                                            to connectedCountry: String? = nil) -> MainRobot {
            // verify Disconnect button appears
            XCTAssert(app.buttons[Localizable.disconnect].waitForExistence(timeout: 10), "'\(Localizable.disconnect)' button not found.")
            
            // verify correct connected protocol appears
            let actualProtocol = app.staticTexts["protocolLabel"].value as! String
            
            if case .Smart = expectedProtocol {
                XCTAssertTrue(!actualProtocol.isEmpty, "Connection protocol for Smart protocol should not be empty")
            } else {
                XCTAssertEqual(expectedProtocol.rawValue, actualProtocol, "Invalid protocol shown, expected: \(expectedProtocol), actual: \(actualProtocol)")
            }
            
            // verify IP Address label appears
            let actualIPAddress = app.staticTexts["ipLabel"].value as! String
            XCTAssertTrue(validateIPAddress(from: actualIPAddress), "IP label \(actualIPAddress) does not contain valid IP address")
            
            // verify header label contain country code
            validateHeaderLabel(value: connectedCountry)
            
            return MainRobot()
        }
        
        @discardableResult
        func checkConnectionCardIsDisconnected() -> MainRobot {
            // verify "Quick Connect" button is visible
            XCTAssert(app.buttons[Localizable.quickConnect].waitForExistence(timeout: 5), "'\(Localizable.quickConnect)' button not found.")
            
            // verify "You are not connected" label if visible
            validateHeaderLabel(value: Localizable.youAreNotConnected)
            
            // verify IP adddress label is displayed and not empty
            let actualIPAddress = app.staticTexts["ipLabel"].value as! String
            XCTAssertTrue(validateIPAddress(from: actualIPAddress), "IP label \(actualIPAddress) does not contain valid IP address")
            return MainRobot()
        }
        
        func checkCountryFound(country: String) -> MainRobot {
            let countryListTable = app.tables["ServerListTable"]
            XCTAssertTrue(countryListTable.waitForExistence(timeout: 2), "Countries list table does not appear")
            XCTAssertEqual(countryListTable.tableRows.count, 2, "Countries list table has incorrect number of rows")
            
            let countryCell = countryListTable.cells[country]
            XCTAssertTrue(countryCell.exists, "\(country) cell is not visible at the countries list table")
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
        
        private func validateHeaderLabel(value: String? = nil) {
            // validate "headerLabel" exist
            XCTAssert(app.staticTexts["headerLabel"].waitForExistence(timeout: 5),
                      "headerLabel textfield was not found.")
            let actualHeaderLabelValue = app.staticTexts["headerLabel"].value as! String
            
            if let expectedValue = value {
                // validate headerLabel has exact value
                XCTAssertTrue(actualHeaderLabelValue.contains(expectedValue),
                               "headerLabel textfield does not contain expected value: \(expectedValue), actual value: \(actualHeaderLabelValue)")
            } else {
                // validate headerLabel is not empty
                XCTAssertTrue(!actualHeaderLabelValue.isEmpty, "headerLabel textfield shold not be empty")
            }
        }
    }
}
