//
//  ConnectionStatusRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import XCTest
import UITestsHelpers
import Strings

fileprivate let statusNotConnected = Localizable.notConnected
fileprivate let statusConnected = Localizable.connectedTo
fileprivate let tabQCInactive = "quick connect inactive button"
fileprivate let tabQCActive = "quick connect active button"
fileprivate let netshieldUpgradeButton = Localizable.upgrade
fileprivate let getPlusButton = "GetPlusButton"
fileprivate let notNowbutton = "UseFreeButton"
fileprivate let connectionStatusUnprotected = Localizable.connectionStatusUnprotected
fileprivate let disconnectButtonId = "disconnect_button"
fileprivate let connectionStatusProtected = Localizable.connectionStatusProtected
fileprivate let connectionInforHeaderId = "connection_info_header"
fileprivate let netShieldStatsViewId = "net_shield_stats"
fileprivate let locationTextId = "location_text"

class ConnectionStatusRobot: CoreElements {
    
    let verify = Verify()

    @discardableResult
    public func isConnected() -> Bool {
        return staticText(connectionStatusProtected)
            .waitUntilExists(time: 1)
            .exists()
    }

    class Verify: CoreElements {

        @discardableResult
        func connectedToAServer(_ name: String) -> HomeRobot {
            staticText(connectionStatusProtected)
                .waitUntilExists(time: 30)
                .checkExists(message: "Not conneted to the \(name) server in 30 seconds")
            staticText(connectionInforHeaderId)
                .firstMatch()
                .checkExists()
                .checkHasLabel(name)
            return HomeRobot()
        }
        
        @discardableResult
        func connectedToASecureCoreServer(_ secureCoreServerName: String) -> ConnectionStatusRobot {
            button(secureCoreServerName)
                .waitUntilExists(time: 30)
                .checkExists(message: "Not connected to the secure core server '\(secureCoreServerName)' server in 30 seconds")
            button(disconnectButtonId).waitUntilExists().checkExists()
            return ConnectionStatusRobot()
        }
        
        @discardableResult
        func connectionStatusNotConnected() -> HomeRobot {
            staticText(connectionStatusUnprotected)
                .waitUntilExists(time: 30)
                .checkExists(message: "Failed to check that connection status is not connected. '\(connectionStatusUnprotected)' label is not visible.")
            if let locationText = staticText(locationTextId)
                .checkExists(message: "Location text is not visible")
                .label() {

                if let result = splitCountryAndIP(from: locationText) {
                    XCTAssertTrue(
                        result.ipAddress.isValidIPv4Address,
                        "\(result.ipAddress) is not valid ipv4 address."
                    )
                    XCTAssertFalse(
                        result.country.isEmpty,
                        "\(result.country) should not be empty"
                    )
                } else {
                    XCTFail("Failed to parse the location text.")
                }
            } else {
                XCTFail("\(locationTextId) label should not be empty")
            }
            return HomeRobot()
        }
        
        @discardableResult
        func connectionStatusConnected<T: CoreElements>(robot _: T.Type = HomeRobot.self) -> T {
            button(disconnectButtonId)
                .waitUntilExists(time: 10)
                .checkExists(message: "Disconnect button is not visible in 10 seconds")
            staticText(connectionStatusProtected)
                .waitUntilExists(time: 60)
                .checkExists(message: "\(connectionStatusProtected) is not visible in 60 seconds")
            staticText(netShieldStatsViewId).checkExists(message: "NetShieldStats view is not visible")
            return T()
        }
        
        @discardableResult
        func protocolNameIsCorrect(_ expectedProtocol: ConnectionProtocol) -> ConnectionStatusRobot {
            if case .Smart = expectedProtocol {
                staticText("Protocol").checkExists()
            } else {
                staticText(expectedProtocol.rawValue).waitUntilExists(time: 30).checkExists()
            }
            return ConnectionStatusRobot()
        }
        
        func upsellModalIsShown() -> ConnectionStatusRobot {
            button(getPlusButton).waitUntilExists().checkExists()
            button(notNowbutton).tap()
            return ConnectionStatusRobot()
        }

        private func splitCountryAndIP(from input: String) -> (country: String, ipAddress: String)? {
            let pattern = "^(.*) • ([0-9]{1,3}(\\.[0-9]{1,3}){3})$"

            do {
                let regex = try NSRegularExpression(pattern: pattern)
                if let match = regex.firstMatch(in: input, range: NSRange(location: 0, length: input.utf16.count)) {
                    if let countryRange = Range(match.range(at: 1), in: input),
                       let ipAddressRange = Range(match.range(at: 2), in: input) {
                        let country = String(input[countryRange])
                        let ipAddress = String(input[ipAddressRange])
                        return (country, ipAddress)
                    }
                }
            } catch {
                XCTFail("Invalid regex: \(error.localizedDescription)")
            }
            return nil
        }
    }
}
