//
//  Created on 20/11/24.
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

@MainActor
class CountriesConnectionTests: ConnectionTestsBase {

    func testConnectAndDisconnectViaCountry() async throws {

        let (countryName, _) = try await ServersListUtils.getRandomCountry()
        let back = "Countries"

        login(as: UserType.Plus.credentials)
            .goToCountriesTab()
            .searchForServer(serverName: countryName)
            .verify.serverFound(server: countryName)
            .hitPowerButton(server: countryName)
            .verify.connectedToAServer(countryName)
            .goToCountriesTab()
            .searchForServer(serverName: countryName)
            .hitPowerButton(server: countryName)

        CountrySearchRobot()
            .clearSearch()

        homeRobot
            .backToPreviousTab(robot: HomeRobot.self, back)
            .goToHomeTab()
            .verify.connectionStatusNotConnected()
    }

    func testConnectAndDisconnectViaServer() async throws {

        let (countryName, _) = try await ServersListUtils.getRandomCountry()

        login(as: UserType.Plus.credentials)
            .goToCountriesTab()
            .openServerList(countryName)
            .verify.serverListIsOpened(countryName)
            .connectToAServerViaServer()
            .verify.connectedToAServer(countryName)
            .goToCountriesTab()
            .openServerList(countryName)
            .verify.serverListIsOpened(countryName)
            .disconnectFromAServerViaServer()
            .goToHomeTab()
            .verify.connectionStatusNotConnected()
    }

    func testConnectionViaSecureCore() {

        let protocolName = ConnectionProtocol.WireGuardUDP

        login(as: UserType.Plus.credentials)
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(protocolName)
            .returnToSettings()
        homeRobot
            .goToCountriesTab()
            .secureCoreOn()

        let secureCoreCountry = countryListRobot.getRandomServerFromList()

        countryListRobot
            .connectToCountry(secureCoreCountry)
            .verify.connectedToAServer(secureCoreCountry)
            //TODO: verify connection details
            .quickDisconnectViaQCButton()
            .verify.connectionStatusNotConnected()
            .goToCountriesTab()
            .secureCoreOFf()
    }

    func testConnectionWithAllSettingsOn() {

        let protocolName = ConnectionProtocol.Smart
        let netshield = "Block malware, ads, & trackers"

        login(as: UserType.Plus.credentials)
            .goToSettingsTab()
            .goToProtocolsList()
            .chooseProtocol(protocolName)
            .returnToSettings()
            .selectNetshield(netshield)
            .turnKillSwitchOn()
            .turnModerateNatOn()
        homeRobot
            .goToCountriesTab()
            .secureCoreOn()

        let secureCoreCountry = countryListRobot.getRandomServerFromList()

        countryListRobot
            .connectToCountry(secureCoreCountry)
            .verify.connectedToAServer(secureCoreCountry)
            //TODO: verify connection details
    }

    func testReconnectionViaWithKsOn() async throws {
        let (countryToReconnectName, _) = try await ServersListUtils.getRandomCountry()

        login(as: UserType.Plus.credentials)
            .goToSettingsTab()
            .turnKillSwitchOn()
        homeRobot
            .goToHomeTab(robot: HomeRobot.self)
            .quickConnectViaQCButton()
            .verify.connectionStatusConnected()
            .goToCountriesTab()
            .openServerList(countryToReconnectName)
            .verify.serverListIsOpened(countryToReconnectName)
            .connectToAServerViaServer()
            .verify.connectedToAServer(countryToReconnectName)
            .quickDisconnectViaQCButton()
            .verify.connectionStatusNotConnected()
    }
}
