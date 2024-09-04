//
//  Created on 17/04/2024.
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
import fusion
import ProtonCoreLog
import ProtonCoreTestingToolkitUITestsCore
import ProtonCoreTestingToolkitPerformance
import XCTest

class MainMeasurements: ProtonVPNUITests {
    private let loginRobot = LoginRobot()
    private let countryListRobot = CountryListRobot()
    private let connectionStatusRobot = ConnectionStatusRobot()
    private lazy var credentials = getCredentials(from: "credentials")
    
    private let workflow = "main_measurements"
    private var measurementContext = MeasurementContext(MeasurementConfig.self)
    
    override class func setUp() {
        super.setUp()
        
        let lokiEndpoint = ObfuscatedConstants.lokiDomain + "loki/api/v1/push"
        
        MeasurementConfig
            .setBundle(Bundle(identifier: Bundle.main.bundleIdentifier!)!)
            .setProduct("VPN")
            .setLokiEndpoint(lokiEndpoint)
            .setEnvironment("prod")
    }
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testLoginSLI() {
        let measurementProfile = measurementContext.setWorkflow(workflow, forTest: self.name)
        
        measurementProfile
            .addMeasurement(DurationMeasurement())
            .setServiceLevelIndicator("login")
        
        loginRobot
            .enterCredentials(credentials[2])
            .signIn(robot: MainRobot.self)
        
        measurementProfile.measure {
            mainRobot
                .verify.connectionStatusNotConnected()
        }
    }
    
    func testConnectionSLI() {
        let measurementProfile = measurementContext.setWorkflow(workflow, forTest: self.name)
        
        measurementProfile
            .addMeasurement(DurationMeasurement())
            .setServiceLevelIndicator("quick_connect")
        
        loginRobot
            .enterCredentials(credentials[2])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .quickConnectViaQCButton()
        
        measurementProfile.measure {
            connectionStatusRobot
                .verify.connectionStatusConnected(robot: MainRobot.self)
        }
        
        mainRobot
            .quickDisconnectViaQCButton()
            .verify.disconnectedFromAServer()
    }
    
    func testConnectionToSpecificServer() {
        let measurementProfile = measurementContext.setWorkflow(workflow, forTest: self.name)
        
        measurementProfile
            .addMeasurement(DurationMeasurement())
            .setServiceLevelIndicator("specific_server_connect")
        
        let countryName = "Australia"
        let back = "Countries"
        
        loginRobot
            .enterCredentials(credentials[2])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        
        mainRobot
            .goToCountriesTab()
            .connectToAServer()
        
        measurementProfile.measure {
            connectionStatusRobot
                .verify.connectedToAServer(countryName)
        }
        
        mainRobot
            .backToPreviousTab(robot: CountryListRobot.self, back)
            .disconnectViaCountry()
            .verify.connectionStatusNotConnected()
    }
}
