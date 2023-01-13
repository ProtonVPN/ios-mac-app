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
import LocalFeatureFlags
import ProtonCore_Networking
import XCTest
@testable import vpncore

class TelemetryAPIImplementationMock: TelemetryAPI {
    var events = [ConnectionEvent]()
    func flushEvent(event: ConnectionEvent) {
        events.append(event)
    }
}

class TelemetryMockFactory: AppStateManagerFactory, NetworkingFactory, PropertiesManagerFactory, VpnKeychainFactory, TelemetryAPIFactory {

    lazy var telemetryApiMock = TelemetryAPIImplementationMock()

    func makeTelemetryAPI(networking: Networking) -> TelemetryAPI { telemetryApiMock }

    func makeVpnKeychain() -> VpnKeychainProtocol { VpnKeychainMock() }

    func makeNetworking() -> Networking { NetworkingMock() }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        let mock = PropertiesManagerMock()
        mock.lastConnectedTimeStamp = Date().timeIntervalSince1970 - 10
        return mock
    }

    func makeAppStateManager() -> AppStateManager {
        return appStateManager
    }

    let appStateManager: AppStateManager

    init(appStateManager: AppStateManager) {
        self.appStateManager = appStateManager
    }
}

class TelemetryTimerMock: TelemetryTimer {
    var reportedConnectionDuration: TimeInterval = 0
    var reportedTimeToConnect: TimeInterval = 0
    func updateConnectionStarted(timeInterval: TimeInterval) { }
    func markStartedConnecting() { }
    func markFinishedConnecting() { }
    func markConnectionStoped() { }
    var connectionDuration: TimeInterval? {
        reportedConnectionDuration
    }

    var timeToConnect: TimeInterval? {
        reportedTimeToConnect
    }

    var timeConnecting: TimeInterval? {
        nil
    }
}

class TelemetryServiceTests: XCTestCase {

    var container: TelemetryMockFactory!
    var service: TelemetryService!
    var appStateManager: AppStateManagerMock!
    var timer: TelemetryTimerMock!

    let vpnGateway = VpnGatewayMock()

    override static func setUp() {
        super.setUp()
        setLocalFeatureFlagOverrides(["Telemetry": ["TelemetryOptIn": true]])
    }

    override static func tearDown() {
        setLocalFeatureFlagOverrides(nil)
    }

    override func setUp() async throws {
        try await super.setUp()
        appStateManager = AppStateManagerMock()
        timer = TelemetryTimerMock()
        appStateManager.mockActiveConnection = ConnectionConfiguration.connectionConfig2
        container = TelemetryMockFactory(appStateManager: appStateManager)
        service = await TelemetryService(factory: container, timer: timer)
    }

    func testReportsConnectionEvent() async throws {
        vpnGateway.connection = .connecting
        XCTAssert(container.telemetryApiMock.events.isEmpty)
        timer.reportedTimeToConnect = 0.5
        vpnGateway.connection = .connected
        guard let lastEvent = container.telemetryApiMock.events.last,
              case .vpnConnection(timeToConnection: let timeToConnection) = lastEvent.event else {
            XCTFail("Expected a vpnConnection event")
            return
        }
        XCTAssertEqual(timeToConnection, 0.5, accuracy: 0.1)
        XCTAssertEqual(lastEvent.dimensions.outcome, .success)
        XCTAssertEqual(lastEvent.dimensions.userTier, .free)
        XCTAssertEqual(lastEvent.dimensions.vpnStatus, .off)
        XCTAssertEqual(lastEvent.dimensions.vpnTrigger, nil)
//        XCTAssertEqual(lastEvent.dimensions.networkType, .unavailable) // this assert is unstable
        XCTAssertEqual(lastEvent.dimensions.serverFeatures, .zero)
        XCTAssertEqual(lastEvent.dimensions.vpnCountry, "PL")
        XCTAssertEqual(lastEvent.dimensions.userCountry, "")
        XCTAssertEqual(lastEvent.dimensions.protocol, .ike)
        XCTAssertEqual(lastEvent.dimensions.server, "")
        XCTAssertEqual(lastEvent.dimensions.port, "500")
        XCTAssertEqual(lastEvent.dimensions.isp, "")
    }

    func testReportsDisconnectionEvent() async throws {
        vpnGateway.connection = .connected
        timer.reportedConnectionDuration = 15.1
        vpnGateway.connection = .disconnected
        guard let lastEvent = container.telemetryApiMock.events.last,
              case .vpnDisconnection(sessionLength: let sessionLength) = lastEvent.event else {
            XCTFail("Expected a vpnConnection event")
            return
        }
        XCTAssertEqual(sessionLength, 15.1, accuracy: 0.1)
        XCTAssertEqual(lastEvent.dimensions.outcome, .failure) // not resulting from user's disconnection
        XCTAssertEqual(lastEvent.dimensions.userTier, .free)
        XCTAssertEqual(lastEvent.dimensions.vpnStatus, .on)
        XCTAssertEqual(lastEvent.dimensions.vpnTrigger, nil)
        XCTAssertEqual(lastEvent.dimensions.serverFeatures, .zero)
        XCTAssertEqual(lastEvent.dimensions.vpnCountry, "PL")
        XCTAssertEqual(lastEvent.dimensions.userCountry, "")
        XCTAssertEqual(lastEvent.dimensions.protocol, .ike)
        XCTAssertEqual(lastEvent.dimensions.server, "")
        XCTAssertEqual(lastEvent.dimensions.port, "500")
        XCTAssertEqual(lastEvent.dimensions.isp, "")
    }

    func testDuplicateNotificationDoNotGenerateMultipleEvents() {
        vpnGateway.connection = .connecting
        XCTAssert(container.telemetryApiMock.events.isEmpty)
        vpnGateway.connection = .connected
        XCTAssertEqual(container.telemetryApiMock.events.count, 1)
        vpnGateway.connection = .connected
        XCTAssertEqual(container.telemetryApiMock.events.count, 1)
        vpnGateway.connection = .disconnected
        XCTAssertEqual(container.telemetryApiMock.events.count, 2)
        vpnGateway.connection = .disconnected
        XCTAssertEqual(container.telemetryApiMock.events.count, 2)
    }
}
