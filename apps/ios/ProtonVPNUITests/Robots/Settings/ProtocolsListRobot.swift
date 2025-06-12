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
import Strings

private let smartButton = Localizable.smartTitle
private let settingsButtonId = "Settings back btn"
private let stealthButton = Localizable.wireguardTls

class ProtocolsListRobot: CoreElements {
    @discardableResult
    func stealthProtocolOn() -> ProtocolsListRobot {
        cell(stealthButton).tap()
        return ProtocolsListRobot()
    }

    @discardableResult
    func smartProtocolOn() -> ProtocolsListRobot {
        cell(smartButton).tap()
        return ProtocolsListRobot()
    }

    @discardableResult
    func returnToSettings() -> SettingsRobot {
        button(settingsButtonId).tap()
        return SettingsRobot()
    }

    /// Choose protocol from the protocol list
    /// - Precondition: Default protocol is Smart
    @discardableResult
    func chooseProtocol(_ connectionProtocol: ConnectionProtocol) -> ProtocolsListRobot {
        cell(connectionProtocol.rawValue).tap()
        return ProtocolsListRobot()
    }
}
