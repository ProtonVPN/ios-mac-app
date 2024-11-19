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

class ConnectionStatusRobot: CoreElements {
    
    let verify = Verify()

    @discardableResult
    func disconnectFromAServer() -> ConnectionStatusRobot {
        button(tabQCActive).tap()
        return ConnectionStatusRobot()
    }

    class Verify: CoreElements {

        @discardableResult
        func connectedToAServer(_ name: String) -> HomeRobot {
            staticText(NSPredicate(format: "label CONTAINS[cd] %@", "Connected to \(name)")).waitUntilExists(time: 30).checkExists()
            button(tabQCActive).waitUntilExists().checkExists()
            return HomeRobot()
        }
        
        @discardableResult
        func connectedToASecureCoreServer(_ secureCoreServerName: String) -> ConnectionStatusRobot {
            let predicate = NSPredicate(format: "label CONTAINS[cd] %@ AND label CONTAINS[cd] %@ AND label CONTAINS[cd] %@", ">>", secureCoreServerName, statusConnected)
            staticText(predicate).waitUntilExists(time: 30).checkExists()
            button(tabQCActive).waitUntilExists().checkExists()
            return ConnectionStatusRobot()
        }
        
        @discardableResult
        func disconnectedFromAServer() -> HomeRobot {
            staticText(statusNotConnected).waitUntilExists().checkExists()
            button(tabQCInactive).waitUntilExists().checkExists()
            return HomeRobot()
        }
        
        @discardableResult
        func connectionStatusNotConnected() -> CountryListRobot {
            staticText("Not Connected").waitUntilExists(time: 10).checkExists()
            return CountryListRobot()
        }

        @discardableResult
        func connectionStatusConnected<T: CoreElements>(robot _: T.Type) -> T {
            button(tabQCActive).waitUntilExists(time: 10).checkExists()
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
    }
}
