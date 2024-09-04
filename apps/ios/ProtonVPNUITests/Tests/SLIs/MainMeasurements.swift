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
import ProtonCoreTestingToolkitUITestsLogin

class MainMeasurements: ProtonVPNUITests {
    private let loginRobot = LoginRobot()
    private let lokiClient = LokiApiClient()
    private let timer = TestsTimer()
    private lazy var credentials = getCredentials(from: "credentials")
    
    private let workflow = "main_measurements"
    private var sli: String? = nil
    private var metrics: Codable? = nil
    private let lokiID = UUID().uuidString
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    func testLoginPerformance() {
        sli = "login"
        
        loginRobot
            .enterCredentials(credentials[2])
        timer.StartTimer()
        loginRobot
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
        timer.EndTimer()
        
        metrics = LoginMetrics(duration: timer.GetElapsedTime(), status: "passed")
    }
    
    override func tearDown() {
        if testRun!.failureCount != 0 {
            metrics = FailureMetrics(status: "failed")
        }
        lokiClient.pushMetrics(id: lokiID, workflow: workflow, sli: sli!, metrics: metrics!)
        super.tearDown()
    }
}
