//
//  Created on 2022-07-15.
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
@testable import LegacyCommon
import XCTest
import Timer
import TimerMock
import VPNSharedTesting
import ProtonCoreNetworking
import ProtonCoreTestingToolkitUnitTestsCore

class AppSessionRefreshTimerTests: XCTestCase {
    var alertService: CoreAlertServiceDummy!
    var propertiesManager: PropertiesManagerMock!
    var serverStorage: ServerStorageMock!
    var networking: NetworkingMock!
    var networkingDelegate: FullNetworkingMockDelegate!
    var apiService: VpnApiService!
    var vpnKeychain: VpnKeychainMock!
    var appSessionRefresher: AppSessionRefresherMock!
    var timerFactory: TimerFactoryMock!
    var appSessionRefreshTimer: AppSessionRefreshTimer!
    var authKeychain: MockAuthKeychain!

    let testData = MockTestData()
    let location: MockTestData.VPNLocationResponse = .mock

    override func setUp() {
        super.setUp()
        alertService = CoreAlertServiceDummy()
        propertiesManager = PropertiesManagerMock()
        serverStorage = ServerStorageMock(servers: [testData.server1, testData.server2, testData.server3])
        networking = NetworkingMock()
        networkingDelegate = FullNetworkingMockDelegate()

        networking.delegate = networkingDelegate
        vpnKeychain = VpnKeychainMock()
        authKeychain = MockAuthKeychain()
        apiService = VpnApiService(networking: networking, vpnKeychain: vpnKeychain, countryCodeProvider: CountryCodeProviderImplementation(), authKeychain: authKeychain)
        appSessionRefresher = AppSessionRefresherMock(factory: self)
        timerFactory = TimerFactoryMock()
        appSessionRefreshTimer = AppSessionRefreshTimerImplementation(
            factory: self,
            refreshIntervals: (full: 30, loads: 20, account: 10, streaming: 60, partners: 60),
            delegate: self
        )
    }

    override func tearDown() {
        super.tearDown()
        alertService = nil
        propertiesManager = nil
        serverStorage = nil
        networking = nil
        networkingDelegate = nil
        apiService = nil
        vpnKeychain = nil
        appSessionRefresher.didAttemptLogin = nil // Prevents crashes in other tests
        appSessionRefresher = nil
        timerFactory = nil
        appSessionRefreshTimer = nil
    }

    func checkForSuccessfulServerUpdate() {
        for serverUpdate in networkingDelegate.apiServerLoads {
            guard let server = serverStorage.servers[serverUpdate.serverId] else {
                XCTFail("Could not find server with id \(serverUpdate.serverId)")
                continue
            }

            XCTAssertEqual(serverUpdate.serverId, server.id)
            XCTAssertEqual(serverUpdate.score, server.score)
            XCTAssertEqual(serverUpdate.load, server.load)
            XCTAssertEqual(serverUpdate.status, server.status)
        }
    }

    func testRefreshTimer() { // swiftlint:disable:this function_body_length
        let expectations = (
            updateServers: (1...2).map { XCTestExpectation(description: "update server list #\($0)") },
            updateCredentials: (1...2).map { XCTestExpectation(description: "update vpn credentials #\($0)") },
            displayAlert: XCTestExpectation(description: "Alert displayed for old app version")
        )
        authKeychain.setMockUsername("user")

        var (nServerUpdates, nCredUpdates) = (0, 0)

        serverStorage.didUpdateServers = { _ in
            guard nServerUpdates < expectations.updateServers.count else {
                XCTFail("Index out of range")
                return
            }
            expectations.updateServers[nServerUpdates].fulfill()
            nServerUpdates += 1
        }

        vpnKeychain.didStoreCredentials = { _ in
            guard nCredUpdates < expectations.updateCredentials.count else {
                XCTFail("Index out of range")
                return
            }
            expectations.updateCredentials[nCredUpdates].fulfill()
            nCredUpdates += 1
        }

        alertService.alertAdded = { _ in
            expectations.displayAlert.fulfill()
        }

        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(planName: "plus",
                                                                           maxTier: CoreAppConstants.VpnTiers.plus)

        appSessionRefresher.loggedIn = true
        appSessionRefreshTimer.start(now: true) // should immediately proceed to refresh credentials

        wait(for: [expectations.updateCredentials[0]], timeout: 10)
        XCTAssertNotNil(vpnKeychain.credentials)
        XCTAssertEqual(vpnKeychain.credentials?.description,
                       networkingDelegate.apiCredentials?.description)

        networkingDelegate.apiServerLoads = [
            .init(serverId: testData.server1.id, load: 10, score: 1.2345, status: 0),
            .init(serverId: testData.server2.id, load: 20, score: 2.3456, status: 1),
            .init(serverId: testData.server3.id, load: 30, score: 3.4567, status: 2),
        ]
        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(planName: "visionary",
                                                                           maxTier: CoreAppConstants.VpnTiers.internal)
        timerFactory.runRepeatingTimers()
        wait(for: [expectations.updateServers[0],
                   expectations.updateCredentials[1]], timeout: 10)
        XCTAssertNotNil(vpnKeychain.credentials)
        XCTAssertEqual(vpnKeychain.credentials?.description,
                       networkingDelegate.apiCredentials?.description)
        checkForSuccessfulServerUpdate()

        networkingDelegate.apiServerLoads = [
            .init(serverId: testData.server3.id, load: 10, score: 1.2345, status: 0),
            .init(serverId: testData.server1.id, load: 20, score: 2.3456, status: 1),
            .init(serverId: testData.server2.id, load: 30, score: 3.4567, status: 2),
        ]
        networkingDelegate.apiCredentials = nil

        let message = "Your app is really, really old"
        appSessionRefresher.loginError = ResponseError(
            httpCode: 400,
            responseCode: ApiErrorCode.apiVersionBad,
            userFacingMessage: message,
            underlyingError: nil
        )

        timerFactory.runRepeatingTimers()
        wait(for: [expectations.updateServers[1], expectations.displayAlert], timeout: 10)
        checkForSuccessfulServerUpdate()

        guard let alert = alertService.alerts.last as? AppUpdateRequiredAlert else {
            XCTFail("Displayed wrong kind of alert during app info refresh")
            return
        }

        XCTAssertEqual(alert.message, message, "Should have displayed alert returned from API")

        appSessionRefreshTimer.stop()

        for timer in timerFactory.repeatingTimers {
            XCTAssertFalse(timer.isValid, "Should have stopped all timers")
        }

        // This part causes crash in tests that I was unable to debug.
        // If zombies are enabled, following error logs can be found:
        // * Class _NSZombie__NSJSONWriter is implemented in both ?? (0x600001f2f000) and ?? (0x600001fb1da0). One of the two will be used. Which one is undefined.
        // * Class _NSZombie___NSConcreteURLComponents is implemented in both ?? (0x600005f688a0) and ?? (0x600005ffc390). One of the two will be used. Which one is undefined.
        // * *** -[CFString release]: message sent to deallocated instance
        //
        // If you tried fixing this and failed, increase the counter :)
        // Failed attempts: 1

//        appSessionRefresher.didAttemptLogin = {
//            XCTFail("Shouldn't call attemptSilentLogin in start(), timeout interval has not yet passed")
//        }
//        serverStorage.didUpdateServers = { _ in
//            XCTFail("Shouldn't call refreshLoads in start(), timeout interval has not yet passed")
//        }
//        vpnKeychain.didStoreCredentials = { _ in
//            XCTFail("Shouldn't call store(credentials:) in start(), timeout interval has not yet passed")
//        }
//        appSessionRefreshTimer.start(now: true)
//        sleep(2) // give time to make sure API isn't being hit
//        appSessionRefreshTimer.stop()
    }
}

extension AppSessionRefreshTimerTests: VpnApiServiceFactory, VpnKeychainFactory, PropertiesManagerFactory, ServerStorageFactory, CoreAlertServiceFactory, AppSessionRefresherFactory, TimerFactoryCreator {

    func makeTimerFactory() -> TimerFactory {
        return timerFactory
    }

    func makeCoreAlertService() -> CoreAlertService {
        return alertService
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }

    func makeServerStorage() -> ServerStorage {
        return serverStorage
    }

    func makeVpnApiService() -> VpnApiService {
        return apiService
    }

    func makeVpnKeychain() -> VpnKeychainProtocol {
        return vpnKeychain
    }

    func makeAppSessionRefresher() -> AppSessionRefresher {
        return appSessionRefresher
    }
}

extension AppSessionRefreshTimerTests: AppSessionRefreshTimerDelegate {
}
