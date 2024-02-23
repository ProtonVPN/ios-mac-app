//
//  Created on 23/02/2024.
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
import XCTest
import Dependencies
import VPNShared
import VPNSharedTesting
@testable import LegacyCommon

class PropertiesManagerTests: XCTestCase {

    var sut: PropertiesManagerProtocol!

    override func invokeTest() {
        withDependencies {
            $0.storage = MemoryStorage()
            $0.dataManager = .mock(data: nil) // stores telemetry in buffer, not relevant to telemetry tests here
            let keychain = MockAuthKeychain()
            keychain.setMockUsername("user")
            $0.authKeychain = keychain
        } operation: {
            super.invokeTest()
        }
    }

    override func setUp() {
        super.setUp()
        sut = PropertiesManager()
    }

    func testTelemetrySettingsDefaultValueIsTrue() {
        XCTAssertTrue(sut.getTelemetryUsageData())
        XCTAssertTrue(sut.getTelemetryCrashReports())
    }

    func testTelemetrySettingsCanSetToFalse() async throws {
        await sut.setTelemetryUsageData(enabled: false)
        sut.setTelemetryCrashReports(enabled: false)
        XCTAssertFalse(sut.getTelemetryUsageData())
        XCTAssertFalse(sut.getTelemetryCrashReports())
    }

    func testTelemetrySettingsCanSetToTrue() async throws {
        await sut.setTelemetryUsageData(enabled: true)
        sut.setTelemetryCrashReports(enabled: true)
        XCTAssertTrue(sut.getTelemetryUsageData())
        XCTAssertTrue(sut.getTelemetryCrashReports())
    }

    func testTelemetryMigratingFromBoolValue() {
        withDependencies {
            $0.storage = MemoryStorage(initialValue: ["TelemetryUsageDatauser": false,
                                                      "TelemetryCrashReportsuser": false])
        } operation: {
            XCTAssertFalse(sut.getTelemetryUsageData())
            XCTAssertFalse(sut.getTelemetryCrashReports())
        }
    }

    func testTelemetryUsingStringValue() {
        withDependencies {
            $0.storage = MemoryStorage(initialValue: ["TelemetryUsageDatauser": "false",
                                                      "TelemetryCrashReportsuser": "false"])
        } operation: {
            XCTAssertFalse(sut.getTelemetryUsageData())
            XCTAssertFalse(sut.getTelemetryCrashReports())
        }
    }
}
