//
//  StateAlertTests.swift
//  vpncore - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import CommonNetworking
import CommonNetworkingTestSupport
import Dependencies
import Domain
@testable import LegacyCommon
import Localization
import VPNAppCore
import VPNSharedTesting
import XCTest

class StateAlertTests: XCTestCase {
    let vpnConfig = VpnManagerConfiguration(
        id: UUID(),
        hostname: "",
        serverId: "",
        ipId: "",
        entryServerAddress: "",
        exitServerAddress: "",
        username: "",
        password: "",
        passwordReference: Data(),
        clientPrivateKey: nil,
        vpnProtocol: .ike,
        netShield: .off,
        vpnAccelerator: true,
        bouncing: nil,
        natType: .default,
        safeMode: true,
        ports: [500],
        serverPublicKey: nil,
        portForwarding: true,
        intent: .fastest
    )

    var vpnManager: VpnManagerMock!
    var alertService: CoreAlertServiceDummy!
    @Dependency(\.propertiesManager) private var propertiesManager
    var appStateManager: AppStateManager!
    var clock: TestClock<Duration>!

    override func setUp() {
        super.setUp()
        vpnManager = VpnManagerMock()
        alertService = CoreAlertServiceDummy()
        clock = TestClock()

        let preparer = VpnManagerConfigurationPreparer(alertService: alertService)

        appStateManager = withDependencies {
            $0.continuousClock = clock
        } operation: {
            AppStateManagerImplementation(
                vpnManager: vpnManager,
                alertService: alertService,
                configurationPreparer: preparer,
                vpnAuthentication: VpnAuthenticationMock()
            )
        }
    }

    func testDisconnectingAlertFirtTimeConnecting() {
        vpnManager.state = .disconnecting(ServerDescriptor(username: "", address: ""))

        propertiesManager.hasConnected = false
        appStateManager.prepareToConnect()
        appStateManager.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: .connectionConfig)

        XCTAssertTrue(alertService.alerts.count == 1)
        XCTAssertTrue(alertService.alerts.first is VpnStuckAlert)
    }

    @MainActor
    func testDisconnectingAlertPreviouslyConnected() async throws {
        // This test historically succeeded only due to incorrect mock timer usage.
        // Enabling it would require some changes that we are not super confident in making right now.
        throw XCTSkip()
        let clock = TestClock()
        vpnManager.state = .disconnecting(ServerDescriptor(username: "", address: ""))

        await withDependencies {
            $0.continuousClock = clock
        } operation: {
            let connectionExpectations = (1 ... 2).map {
                XCTestExpectation(description: "Connection attempt \($0) initiated")
            }
            var connectionAttempt = 0
            vpnManager.didDisconnectAndPrepareToConnect = { _ in
                defer { connectionAttempt += 1 }
                guard connectionExpectations.indices.contains(connectionAttempt) else {
                    XCTFail("Number of connection attemps exceeds expected amount")
                    return
                }
                connectionExpectations[connectionAttempt].fulfill()
            }

            propertiesManager.hasConnected = true
            appStateManager.prepareToConnect()
            appStateManager.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: .connectionConfig)
            await fulfillment(of: [connectionExpectations[0]], timeout: 1)

            // Wait for first connection attempt to time out
            await clock.advance(by: .seconds(40))

            // The connection attempt should be restarted
            await fulfillment(of: [connectionExpectations[1]], timeout: 10)

            let alertPresented = XCTestExpectation(description: "An alert should have been presented")
            alertService.alertAdded = { alert in
                alertPresented.fulfill()
                XCTAssert(alert is VpnStuckAlert)
            }
            XCTAssertTrue(alertService.alerts.isEmpty)

            // Wait for retry to fail
            await clock.advance(by: .seconds(35))

            await fulfillment(of: [alertPresented], timeout: 1)
            XCTAssertEqual(alertService.alerts.count, 1)
        }
    }

    func testNormalConnectingNoAlerts() {
        propertiesManager.hasConnected = true
        appStateManager.prepareToConnect()
        appStateManager.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: .connectionConfig)

        XCTAssertTrue(alertService.alerts.isEmpty)
    }
}

extension ConnectionConfiguration {
    static var connectionConfig: ConnectionConfiguration {
        let server = ServerModel(
            id: "",
            name: "",
            domain: "",
            load: 0,
            entryCountryCode: "",
            exitCountryCode: "",
            tier: 1,
            feature: .zero,
            city: nil,
            ips: [ServerIp](),
            score: 0.0,
            status: 0,
            location: ServerLocation(lat: 0, long: 0),
            hostCountry: nil,
            translatedCity: nil,
            gatewayName: nil
        )
        let serverIp = ServerIp(
            id: "",
            entryIp: "",
            exitIp: "",
            domain: "",
            status: 0
        )
        return ConnectionConfiguration(
            id: UUID(),
            server: server,
            serverIp: serverIp,
            vpnProtocol: .ike,
            netShieldType: .off,
            natType: .default,
            safeMode: true,
            portForwarding: true,
            ports: [500],
            intent: .fastest
        )
    }

    static var connectionConfig2: ConnectionConfiguration {
        let server = ServerModel(
            id: "",
            name: "",
            domain: "",
            load: 0,
            entryCountryCode: "CZ",
            exitCountryCode: "PL",
            tier: 1,
            feature: .zero,
            city: nil,
            ips: [ServerIp](),
            score: 0.0,
            status: 0,
            location: ServerLocation(lat: 0, long: 0),
            hostCountry: nil,
            translatedCity: nil,
            gatewayName: nil
        )
        let serverIp = ServerIp(
            id: "",
            entryIp: "",
            exitIp: "",
            domain: "",
            status: 0
        )
        return ConnectionConfiguration(
            id: UUID(),
            server: server,
            serverIp: serverIp,
            vpnProtocol: .ike,
            netShieldType: .off,
            natType: .default,
            safeMode: true,
            portForwarding: true,
            ports: [500],
            intent: .country("CZ", .fastest)
        )
    }
}
