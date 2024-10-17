//
//  Created on 9/9/24.
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

import Foundation
import ProtonCoreTestingToolkitPerformance
import UITestsHelpers

class MacOSMainMeasurementsTests: ProtonVPNUITests {
    
    private let workflow = "main_measurements"
    private lazy var measurementContext = MeasurementContext(MeasurementConfig.self)
    private let countriesSelectionRobot = CountriesSectionRobot()
    private let mainRobot = MainRobot()
    private let loginRobot = LoginRobot()
    
    override class func setUp() {
        super.setUp()
        
        MeasurementConfig
            .setBundle(Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!)
            .setProduct("VPN")
            .setEnvironment("prod")
            .setLokiEndpoint(ProcessInfo.processInfo.environment["LOKI_ENDPOINT"] ?? "invalid")
            .setLokiCertificate(ProcessInfo.processInfo.environment["CERTIFICATE_IOS_SDK"] ?? "invalid")
            .setLokiCertificatePassphrase(ProcessInfo.processInfo.environment["CERTIFICATE_IOS_SDK_PASSPHRASE"] ?? "invalid")
        
    }
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
    }
    
    override func tearDown() {
        super.tearDown()
        if mainRobot.isConnected() {
            mainRobot.disconnect()
        } else if mainRobot.isConnecting() || mainRobot.isConnectionTimedOut() {
            mainRobot.cancelConnecting()
        }
    }
    
    @MainActor
    func testLoginSLI() {
        let measurementProfile = measurementContext.setWorkflow(workflow, forTest: self.name)
        
        measurementProfile
            .addMeasurement(DurationMeasurement())
            .setServiceLevelIndicator("login")
        
        loginRobot
            .enterCredentials(credentials: UserType.Plus.credentials)
            .signIn()
        
        measurementProfile.measure {
            mainRobot
                .verify.userLoggedIn()
        }
    }
    
    @MainActor
    func testConnectionSLI() {
        let measurementProfile = measurementContext.setWorkflow(workflow, forTest: self.name)

        measurementProfile
            .addMeasurement(DurationMeasurement())
            .setServiceLevelIndicator("quick_connect")
        
        loginAsPlusUser()

        mainRobot
            .verify.userLoggedIn()
            .quickConnectToAServer()

        measurementProfile.measure {
            mainRobot
                .verify.checkDisconnectButtonAppears()
        }
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
    }

    @MainActor
    func testConnectionToSpecificServer() async throws {
        let measurementProfile = measurementContext.setWorkflow(workflow, forTest: self.name)

        measurementProfile
            .addMeasurement(DurationMeasurement())
            .setServiceLevelIndicator("specific_server_connect")

        let randomServer = try await ServersListUtils.getRandomServerName()

        loginAsPlusUser()
        
        mainRobot
            .verify.userLoggedIn()

        countriesSelectionRobot
            .searchForServer(serverName: randomServer)
            .verify.checkAmountOfLocationsFound(expectedAmount: 1)
            .expandCountry()
            .verify.checkServerListContain(server: randomServer)
            .connectToServer(server: randomServer)

        measurementProfile.measure {
            mainRobot
                .verify.checkDisconnectButtonAppears()
        }
        
        mainRobot
            .waitForConnected(with: ConnectionProtocol.Smart)
            .verify.checkConnectionCardIsConnected(with: ConnectionProtocol.Smart)
    }
}
