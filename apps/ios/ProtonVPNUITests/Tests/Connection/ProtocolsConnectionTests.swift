//
//  Created on 19/11/24.
//
//  Copyright (c) 2024 Proton AG
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

import UITestsHelpers
import XCTest

@MainActor
class ProtocolsConnectionTests: ConnectionTestsBase {
    func testConnectViaWireGuardUDPProtocol() {
        testConnection(connectionProtocol: ConnectionProtocol.WireGuardUDP)
    }

    func testConnectViaWireGuardTCPProtocol() {
        testConnection(connectionProtocol: ConnectionProtocol.WireGuardTCP)
    }

    func testConnectViaSmartProtocol() {
        testConnection(connectionProtocol: ConnectionProtocol.Smart)
    }

    func testConnectViaStealthProtocol() {
        testConnection(connectionProtocol: ConnectionProtocol.Stealth)
    }

    func testConnectViaWireGuardUDPProtocolKillSwitchON() {
        testConnection(connectionProtocol: ConnectionProtocol.WireGuardUDP, isKSOn: true)
    }

    func testConnectViaWireGuardTCPProtocolKillSwitchON() {
        testConnection(connectionProtocol: ConnectionProtocol.WireGuardTCP, isKSOn: true)
    }

    func testConnectViaSmartProtocolKillSwitchON() {
        testConnection(connectionProtocol: ConnectionProtocol.Smart, isKSOn: true)
    }

    func testConnectViaStealthProtocolKillSwitchON() {
        testConnection(connectionProtocol: ConnectionProtocol.Stealth, isKSOn: true)
    }

    private func testConnection(connectionProtocol: ConnectionProtocol, isKSOn: Bool = false) {
        login(as: UserType.Plus.credentials)
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(connectionProtocol)
            .returnToSettings()
            .toggleKillSwitch(state: isKSOn)
        homeRobot
            .goToHomeTab(robot: HomeRobot.self)
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected()
            .openConnectionDetails()
            .verify.connectionDetailsIsShown()

        if connectionProtocol != .Smart {
            connectionDetailsRobot
                .verify.connectionDetailsProtocol(name: connectionProtocol.rawValue)
        }
        connectionDetailsRobot

            .closeConnectionDetails()
            .quickDisconnectViaQCButton()
            .verify.connectionStatusNotConnected()
    }
}
