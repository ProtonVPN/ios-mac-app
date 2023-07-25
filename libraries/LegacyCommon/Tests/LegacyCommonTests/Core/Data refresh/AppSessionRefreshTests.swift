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
import LegacyCommonTestSupport
import XCTest
import Timer
import TimerMock
import VPNSharedTesting
import ProtonCoreTestingToolkitUnitTestsCore

class AppSessionRefreshTimerTests: XCTestCase {
    var alertService: CoreAlertServiceDummy!
    var propertiesManager: PropertiesManagerMock!
    var serverStorage: ServerStorageMock!
    var networking: NetworkingMock!
    var networkingDelegate: FullNetworkingMockDelegate!
    var apiService: VpnApiService!
    var vpnKeychain: VpnKeychainMock!
    var appSessionRefresher: BaseAppSessionRefresher!
    var timerFactory: TimerFactoryMock!
    var appSessionRefreshTimer: AppSessionRefreshTimer!
    var authKeychain: MockAuthKeychain!

    let testData = MockTestData()

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
        appSessionRefresher = BaseAppSessionRefresher(factory: self)
        timerFactory = TimerFactoryMock()
        appSessionRefreshTimer = AppSessionRefreshTimer(factory: self,
                                                        refreshIntervals: (full: 30, server: 20, account: 10))
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
            expectations.updateServers[nServerUpdates].fulfill()
            nServerUpdates += 1
        }

        vpnKeychain.didStoreCredentials = { _ in
            expectations.updateCredentials[nCredUpdates].fulfill()
            nCredUpdates += 1
        }

        alertService.alertAdded = { _ in
            expectations.displayAlert.fulfill()
        }

        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(accountPlan: .plus,
                                                                           maxTier: CoreAppConstants.VpnTiers.plus)
        propertiesManager.userLocation = try! UserLocation(dic: testData.vpnLocation.toJsonDict.mapValues { $0 as AnyObject })

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
        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(accountPlan: .visionary,
                                                                           maxTier: CoreAppConstants.VpnTiers.visionary)
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
        appSessionRefresher.loginError = ApiError(httpStatusCode: 400,
                                                  code: ApiErrorCode.appVersionBad,
                                                  localizedDescription: message)

        timerFactory.runRepeatingTimers()
        wait(for: [expectations.updateServers[1], expectations.displayAlert], timeout: 10)
        checkForSuccessfulServerUpdate()

        XCTAssertEqual(alertService.alerts.count, 1, "Should have only displayed one alert")
        guard let alert = alertService.alerts.last as? AppUpdateRequiredAlert else {
            XCTFail("Displayed wrong kind of alert during app info refresh")
            return
        }

        XCTAssertEqual(alert.message, message, "Should have displayed alert returned from API")

        appSessionRefreshTimer.stop()
        for timer in timerFactory.repeatingTimers {
            XCTAssertFalse(timer.isValid, "Should have stopped all timers")
        }

        appSessionRefresher.didAttemptLogin = {
            XCTFail("Shouldn't call attemptSilentLogin in start(), timeout interval has not yet passed")
        }
        serverStorage.didStoreNewServers = { _ in
            XCTFail("Shouldn't call refreshLoads in start(), timeout interval has not yet passed")
        }
        vpnKeychain.didStoreCredentials = { _ in
            XCTFail("Shouldn't call store(credentials:) in start(), timeout interval has not yet passed")
        }
        appSessionRefreshTimer.start(now: true)
        sleep(1) // give time to make sure API isn't being hit
        appSessionRefreshTimer.stop()
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

/// This exists because the `attemptSilentLogIn()` function needs to be overridden.
class BaseAppSessionRefresher: AppSessionRefresherImplementation {
    var didAttemptLogin: (() -> Void)?
    var loginError: Error?

    override func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        defer { didAttemptLogin?() }

        if let loginError = loginError {
            completion(.failure(loginError))
            return
        }

        completion(.success)
    }
}
