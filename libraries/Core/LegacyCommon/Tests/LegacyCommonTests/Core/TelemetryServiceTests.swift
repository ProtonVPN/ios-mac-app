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
@testable import LegacyCommon

actor TelemetryAPIImplementationMock: TelemetryAPI {
    var events = [[String: Any]]()
    func flushEvent(event: [String: Any], isBusiness _: Bool) async throws -> LegacyCommon.TelemetryResponse {
        events.append(event)
        return TelemetryResponse(code: 1000)
    }

    func flushEvents(events _: [String: Any], isBusiness _: Bool) async throws -> LegacyCommon.TelemetryResponse {
        TelemetryResponse(code: 1000)
    }
}

class TelemetryMockFactory: AppStateManagerFactory, NetworkingFactory, TelemetrySettingsFactory, TelemetryAPIFactory {
    lazy var telemetryApiMock = TelemetryAPIImplementationMock()

    func makeTelemetryAPI(networking _: Networking) -> TelemetryAPI { telemetryApiMock }

    func makeTelemetrySettings() -> TelemetrySettings { TelemetrySettings() }

    func makeNetworking() -> Networking { NetworkingMock() }

    func makeAppStateManager() -> AppStateManager {
        appStateManager
    }

    let appStateManager: AppStateManager

    init(appStateManager: AppStateManager) {
        self.appStateManager = appStateManager
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
    var container: TelemetryMockFactory!
    var service: TelemetryUpsellReporter!
    var appStateManager: AppStateManagerMock!
    var timer: TelemetryTimerMock!
    var clock: TestClock<Duration>!

    let vpnGateway = VpnGatewayMock()

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
        appStateManager = AppStateManagerMock()
        timer = TelemetryTimerMock()
        appStateManager.mockActiveConnection = ConnectionConfiguration.connectionConfig2
        container = TelemetryMockFactory(appStateManager: appStateManager)

        clock = TestClock()
        service = await withDependencies {
            $0.continuousClock = clock
        } operation: {
            await TelemetryUpsellReporter(
                factory: container,
                telemetryEventScheduler: TelemetryEventScheduler(factory: container, isBusiness: false)
            )
        }
    }

    @MainActor
    func testValueTimeouts() async throws {
        let impl = service as TelemetryUpsellReporter
        impl.setValueTimeout(0.5)
        impl.previousModalSource = .changeServer
        impl.previousOfferReference = "foo bar"

        XCTAssertEqual(impl.previousModalSource, .changeServer)
        XCTAssertEqual(impl.previousOfferReference, "foo bar")

        await clock.advance(by: .seconds(0.5))

        XCTAssertNil(impl.previousModalSource)
        XCTAssertNil(impl.previousOfferReference)
    }
}
