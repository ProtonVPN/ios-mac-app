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
        testConnection(protocol: ConnectionProtocol.WireGuardUDP)
    }

    func testConnectViaWireGuardTCPProtocol() {
        testConnection(protocol: ConnectionProtocol.WireGuardTCP)
    }

    func testConnectViaSmartProtocol() {
        testConnection(protocol: ConnectionProtocol.Smart)
    }

    func testConnectViaStealthProtocol() {
        testConnection(protocol: ConnectionProtocol.Stealth)
    }

    func testConnectViaWireGuardUDPProtocolKillSwitchON() {
        testConnection(protocol: ConnectionProtocol.WireGuardUDP, isKSOn: true)
    }

    func testConnectViaWireGuardTCPProtocolKillSwitchON() {
        testConnection(protocol: ConnectionProtocol.WireGuardTCP, isKSOn: true)
    }

    func testConnectViaSmartProtocolKillSwitchON() {
        testConnection(protocol: ConnectionProtocol.Smart, isKSOn: true)
    }

    func testConnectViaStealthProtocolKillSwitchON() {
        testConnection(protocol: ConnectionProtocol.Stealth, isKSOn: true)
    }

    private func testConnection(protocol: ConnectionProtocol, isKSOn: Bool = false) {
        login(as: UserType.Plus.credentials)
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(ConnectionProtocol.WireGuardUDP)
            .returnToSettings()
            .toggleKillSwitch(state: isKSOn)
        homeRobot
            .goToHomeTab(robot: HomeRobot.self)
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected()
            .quickDisconnectViaQCButton()
            .verify.connectionStatusNotConnected()
    }
}
