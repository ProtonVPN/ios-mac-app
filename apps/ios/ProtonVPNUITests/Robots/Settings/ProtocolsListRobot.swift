//
//  ProtocolsListRobot.swift
//  ProtonVPNUITests
//
//  Created by Marc Flores on 31.08.21.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import XCTest
import UITestsHelpers

fileprivate let smartButton = "Smart"
fileprivate let settingsButton = "Settings back btn"
fileprivate let stealthButton = "Stealth"

class ProtocolsListRobot: CoreElements {
    
    func stealthProtocolOn() -> ProtocolsListRobot {
        cell(stealthButton).tap()
        return ProtocolsListRobot()
    }
    
    func smartProtocolOn() -> ProtocolsListRobot {
        cell(smartButton).tap()
        return ProtocolsListRobot()
    }
    
    @discardableResult
    func returnToSettings() -> SettingsRobot {
        button(settingsButton).tap()
        return SettingsRobot()
    }
    
    /// Choose protocol from the protocol list
    /// - Precondition: Default protocol is Smart
    func chooseProtocol(_ connectionProtocol: ConnectionProtocol) -> ProtocolsListRobot {
        cell(connectionProtocol.rawValue).tap()
        return ProtocolsListRobot()
    }
}
