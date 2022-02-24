//
//  Created on 2022-02-21.
//
//  Copyright (c) 2022 Proton AG
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
import XCTest
import vpncore
@testable import ProtonVPN

fileprivate class ModelIdCheckerMock: ModelIdCheckerProtocol {
    var modelId: String? = nil
}

class ModelIdConnectionInterceptTests: XCTestCase {
    let bgQ = DispatchQueue(label: "Intercept Alerts")
    let properties = PropertiesManagerMock()
    let alerts = CoreAlertServiceMock()
    fileprivate let checker = ModelIdCheckerMock()

    override func setUp() {
        checker.modelId = nil
        properties.killSwitch = false
    }

    func testNonT2Model() {
        properties.killSwitch = true
        checker.modelId = "JetPackPro4,20"

        let intercept = NetworkExtensionT2Intercept(modelIdChecker: checker,
                                                    alertService: alerts,
                                                    propertiesManager: properties)

        do {
            let expectation = XCTestExpectation(description: "Immediately allow connect for non-T2 models")
            bgQ.async {
                intercept.shouldIntercept(.smartProtocol, isKillSwitchOn: true) { interceptResult in
                    if case .intercept = interceptResult {
                        XCTFail("Expected to allow connection")
                    }
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 5)
        }
    }

    func testModelT2InterceptAndReconnectWithoutKS() {
        properties.killSwitch = true
        checker.modelId = ModelIdChecker.macT2ModelNames.first!

        let intercept = NetworkExtensionT2Intercept(modelIdChecker: checker,
                                                    alertService: alerts,
                                                    propertiesManager: properties)

        do {
            let expectation = XCTestExpectation(description: "Get intercept alert")
            bgQ.async {
                intercept.shouldIntercept(.smartProtocol, isKillSwitchOn: true) { interceptResult in
                    switch interceptResult {
                    case .intercept(let parameters):
                        XCTAssertEqual(parameters.newProtocol, .smartProtocol, "Expected to still connect with smart protocol")
                        XCTAssertFalse(parameters.smartProtocolWithoutWireGuard, "Expected to leave smart protocol alone")
                        XCTAssertTrue(parameters.disableKillSwitch, "Expected to disable kill switch")
                    case .allow:
                        XCTFail("Expected to intercept connection")
                    }
                    expectation.fulfill()
                }
            }

            var i = 0
            while alerts.alerts.isEmpty && i < 3 {
                sleep(1)
                i += 1
            }

            guard let alert = alerts.alerts.first as? NEKSOnT2Alert else {
                XCTFail("Didn't get intercept alert")
                return
            }

            alert.killSwitchOffAction.handler?()
            wait(for: [expectation], timeout: 5)
        }
    }

    func testModelT2InterceptContinue() {
        properties.killSwitch = true
        checker.modelId = ModelIdChecker.macT2ModelNames.first!

        let intercept = NetworkExtensionT2Intercept(modelIdChecker: checker,
                                                    alertService: alerts,
                                                    propertiesManager: properties)


        do {
            let expectation = XCTestExpectation(description: "Get intercept alert")
            bgQ.async {
                intercept.shouldIntercept(.smartProtocol, isKillSwitchOn: true) { interceptResult in
                    if case .intercept = interceptResult {
                        XCTFail("Expected to allow connection")
                    }
                    expectation.fulfill()
                }
            }

            var i = 0
            while alerts.alerts.isEmpty && i < 3 {
                sleep(1)
                i += 1
            }

            guard let alert = alerts.alerts.first as? NEKSOnT2Alert else {
                XCTFail("Didn't get intercept alert")
                return
            }

            alert.connectAnywayAction.handler?()
            wait(for: [expectation], timeout: 5)
        }
    }
}
