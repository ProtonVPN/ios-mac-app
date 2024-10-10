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
import fusion

fileprivate let qcButton = Localizable.quickConnect
fileprivate let disconnectButton = Localizable.disconnect
fileprivate let preferencesTitle = Localizable.preferences
fileprivate let menuItemReportAnIssue = Localizable.reportAnIssue
fileprivate let menuItemProfiles = Localizable.overview
fileprivate let statusTitle = Localizable.youAreNotConnected
fileprivate let initializingConnectionTitle = Localizable.initializingConnection
fileprivate let successfullyConnectedTitle = Localizable.successfullyConnected
fileprivate let headerLabelField = "headerLabel"
fileprivate let ipLabelField = "ipLabel"
fileprivate let protocolLabelField = "protocolLabel"

class MainRobot: CoreElements {
    
    func openProfiles() -> ManageProfilesRobot {
        tabGroup(Localizable.profiles).forceTap()
        button(Localizable.createProfile).tap()
        return ManageProfilesRobot()
    }
    
    func openProfilesOverview() -> ManageProfilesRobot {
        openProfiles()
        tabGroup(Localizable.overview).tap()
        return ManageProfilesRobot()
    }
    
    func closeProfilesOverview() -> MainRobot {
        windows(Localizable.profilesOverview).onChild(button(XCUIIdentifierCloseWindow)).tap()
        return self
    }
    
    func openAppSettings() -> SettingsRobot {
        windows().typeKey(",", [.command])
        return SettingsRobot()
    }
    
    func quickConnectToAServer() -> MainRobot {
        button(qcButton).tapInCenter()
        return self
    }
    
    func isConnected() -> Bool {
        return button(disconnectButton).waitUntilExists(time: 1).exists()
    }
    
    func disconnect() -> MainRobot {
        button(disconnectButton).firstMatch().tapInCenter()
        return self
    }
    
    func logOut() -> LoginRobot {
        windows("Proton VPN").typeKey("w", [.shift, .command])
        return LoginRobot()
    }
    
    func waitForInitializingConnectionScreenDisappear(_ timeout: Int) -> Bool {
        return !staticText(initializingConnectionTitle).waitUntilGone(time: TimeInterval(timeout)).exists()
    }
    
    func waitForSuccessfullyConnectedScreenDisappear(_ timeout: Int) -> Bool {
        return !staticText(successfullyConnectedTitle).waitUntilGone(time: TimeInterval(timeout)).exists()
    }
    
    func isConnecting() -> Bool {
        return staticText(initializingConnectionTitle).waitUntilExists(time: 1).exists()
    }
    
    func waitForConnected(with connectionProtocol: ConnectionProtocol) -> MainRobot {
        let connectingTimeout = 5
        guard waitForInitializingConnectionScreenDisappear(connectingTimeout) else {
            XCTFail("VPN is not connected using \(connectionProtocol) in \(connectingTimeout) seconds")
            return MainRobot()
        }

        _ = waitForSuccessfullyConnectedScreenDisappear(connectingTimeout)

        if isConnectionTimedOut() {
            XCTFail("Connection timeout while connecting to \(connectionProtocol) protocol")
        }

        return self
    }

    func cancelConnecting() -> MainRobot {
        button(Localizable.cancel).tap()
        return self
    }
    
    func isConnectionTimedOut() -> Bool {
        return staticText(Localizable.connectionTimedOut).waitUntilGone(time: 1).exists()
    }
    
    func getHeaderLabelValue() -> String {
        return staticText(headerLabelField).value() as? String ?? ""
    }
    
    func getConnectedCountry() -> String {
        return getHeaderLabelValue().trimServerCode
    }
    
    func getIPLabelValue() -> String {
        return staticText(ipLabelField).value() as? String ?? ""
    }
    
    func getProtocolLabelValue() -> String {
        return staticText(protocolLabelField).value() as? String ?? ""
    }
    
    func isAbleToChangeServer() -> Bool {
        return button(Localizable.changeServer).exists()
    }
    
    func clickChangeServer() -> MainRobot {
        let changeServerButton = button(Localizable.changeServer)
        if changeServerButton.exists() {
            changeServerButton.forceTap()
        } else {
            let changeServerLabel = staticText(Localizable.changeServer)
            changeServerLabel.forceTap()
        }
        return self
    }

    let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func checkSettingsModalIsClosed() -> MainRobot {
            windows(preferencesTitle).checkDoesNotExist()
            button(qcButton).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func checkUserIsLoggedIn() -> MainRobot {
            staticText(statusTitle).waitUntilExists(time: WaitTimeout.normal).checkExists()
            button(qcButton).waitUntilExists(time: WaitTimeout.short).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func checkVPNConnecting() -> MainRobot {
            staticText(initializingConnectionTitle).waitUntilExists(time: WaitTimeout.normal).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func checkDisconnectButtonAppears() -> MainRobot {
            // leaving only 1 assertion as it used in performance tests. Adding additional assertion will  increase test time execution increasing performance test results, which will give not accurate execution time
            button(Localizable.disconnect).waitUntilExists(time: WaitTimeout.normal).checkExists()
            return MainRobot()
        }

        @discardableResult
        func checkConnectionCardIsConnected(with expectedProtocol: ConnectionProtocol,
                                            to connectedCountry: String? = nil,
                                            userType: UserType? = nil) -> MainRobot {
            // verify Disconnect button appears
            checkDisconnectButtonAppears()
            
            // verify correct connected protocol appears
            let actualProtocol = MainRobot().getProtocolLabelValue()
            
            if case .Smart = expectedProtocol {
                XCTAssertTrue(!actualProtocol.isEmpty, "Connection protocol for Smart protocol should not be empty")
            } else {
                XCTAssertEqual(expectedProtocol.rawValue, actualProtocol, "Invalid protocol shown, expected: \(expectedProtocol), actual: \(actualProtocol)")
            }
            
            // verify IP Address label appears
            let actualIPAddress = MainRobot().getIPLabelValue()
            XCTAssertTrue(validateIPAddress(from: actualIPAddress), "IP label \(actualIPAddress) does not contain valid IP address")
            
            // verify header label contain country code
            validateHeaderLabel(value: connectedCountry)
            
            if case .Free = userType {
                let predicate = NSPredicate(format: "value CONTAINS[c] %@", Localizable.changeServer)
                let changeServerButton = button(Localizable.changeServer)
                let changeServerTextField = staticText(predicate).firstMatch()
                
                XCTAssertTrue(changeServerButton.exists() || changeServerTextField.exists(), "'\(Localizable.changeServer)' button is not visible when it shoudl be")
                // verify header label contain "FREE" text
                validateHeaderLabel(value: "FREE")
            }
            
            return MainRobot()
        }
        
        func checkConnectedServerContain(label: String) -> MainRobot {
            // verify header label contain label
            validateHeaderLabel(value: label)
            return MainRobot()
        }
        
        @discardableResult
        func userLoggedIn() -> MainRobot {
            // verify "Quick Connect" button is visible
            // leaving only 1 assertion as it used in performance tests. Adding additional assertion will  increase test time execution increasing performance test results, which will give not accurate execution time
            button(Localizable.quickConnect).waitUntilExists(time: WaitTimeout.long).checkExists()
            return MainRobot()
        }

        @discardableResult
        func checkConnectionCardIsDisconnected() -> MainRobot {
            // verify "Quick Connect" button is visible
            button(Localizable.quickConnect).waitUntilExists(time: WaitTimeout.short).checkExists()
            
            // verify "You are not connected" label if visible
            validateHeaderLabel(value: Localizable.youAreNotConnected)
            
            // verify IP adddress label is displayed and not empty
            let actualIPAddress = MainRobot().getIPLabelValue()
            XCTAssertTrue(validateIPAddress(from: actualIPAddress), "IP label \(actualIPAddress) does not contain valid IP address")
            return MainRobot()
        }

        @discardableResult
        func checkIfLocalNetworkingReachable(to defaultGatewayAddress: String) async throws -> MainRobot {
            let success = try await NetworkUtils.isIpAddressAccessible(ipAddress: defaultGatewayAddress)
            if !success {
                XCTFail("Local letwork is not accessbile by ip addess: \(defaultGatewayAddress)")
            }

            return MainRobot()
        }
        
        func checkConnectedServerChanged(connectedServer: String) -> MainRobot {
            let actualConnectedServer = MainRobot().getConnectedCountry()
            
            XCTAssertNotEqual(connectedServer, actualConnectedServer, "Connected server is not changed")
            
            return MainRobot()
        }
        
        func checkIpAddressChanged(previousIpAddress: String) async throws -> String {
            let currentIpAddress = try await NetworkUtils.getIpAddress()
            XCTAssertTrue(currentIpAddress != previousIpAddress, "IP address is not changed. Previous ip address: \(previousIpAddress), current IP address: \(currentIpAddress)")
            return currentIpAddress
        }
        
        func checkIpAddressUnchanged(previousIpAddress: String) async throws {
            let currentIpAddress = try await NetworkUtils.getIpAddress()
            XCTAssertEqual(currentIpAddress, previousIpAddress, "IP address has been changed. Previous ip address: \(previousIpAddress), current IP address: \(currentIpAddress)")
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
            staticText(headerLabelField).waitUntilExists(time: WaitTimeout.short).checkExists()
            let actualHeaderLabelValue = MainRobot().getHeaderLabelValue()
            
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
