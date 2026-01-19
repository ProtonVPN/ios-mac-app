//
//  Created on 04/01/2023.
//
//  Copyright (c) 2023 Proton AG
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

import ProtonCoreNetworking

import CommonNetworking
import CommonNetworkingTestSupport
import VPNShared

import Ergonomics
@testable import Telemetry

actor TelemetryAPIImplementationMock: TelemetryAPI {
    var events = [[String: Any]]()
    func flushEvent(event: [String: Any], isBusiness _: Bool) async throws -> Telemetry.TelemetryResponse {
        events.append(event)
        return TelemetryResponse(code: 1000)
    }

    func flushEvents(events _: [String: Any], isBusiness _: Bool) async throws -> Telemetry.TelemetryResponse {
        TelemetryResponse(code: 1000)
    }
}

class TelemetryTimerMock: TelemetryTimer {
    var reportedConnectionDuration: TimeInterval = 0
    var reportedTimeToConnect: TimeInterval = 0
    func updateConnectionStarted(_: Date?) {}
    func markStartedConnecting() {}
    func markFinishedConnecting() {}
    func markConnectionStopped() {}
    var connectionDuration: TimeInterval {
        reportedConnectionDuration
    }

    var timeToConnect: TimeInterval {
        reportedTimeToConnect
    }

    var timeConnecting: TimeInterval {
        0
    }
}

class TelemetryServiceTests: XCTestCase {
    var service: TelemetryUpsellReporter!
    var timer: TelemetryTimerMock!
    var clock: TestClock<Duration>!

    override static func setUp() {
        super.setUp()
    }

    override func invokeTest() {
        withDependencies { values in
            values.date = .constant(.now)
            values[DataManager.self] = .mock(data: nil)
        } operation: {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        timer = TelemetryTimerMock()

        clock = TestClock()
        service = await withDependencies {
            $0.continuousClock = clock
        } operation: {
            await TelemetryUpsellReporter(
                telemetryEventScheduler: TelemetryEventScheduler(isBusiness: false)
            )
        }
    }

    @MainActor
    func testValueTimeouts() async throws {
        let impl = service as TelemetryUpsellReporter
        impl.previousModalSource = .changeServer
        impl.previousOfferReference = "foo bar"

        XCTAssertEqual(impl.previousModalSource, .changeServer)
        XCTAssertEqual(impl.previousOfferReference, "foo bar")

        impl._expireTimeouts()

        XCTAssertNil(impl.previousModalSource)
        XCTAssertNil(impl.previousOfferReference)
    }
}
