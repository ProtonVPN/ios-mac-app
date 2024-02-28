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
import XCTest

import Dependencies

import ProtonCoreNetworking
import ProtonCoreTestingToolkitUnitTestsCore

@testable import LegacyCommon
import Domain
import Localization
import Persistence
import PersistenceTestSupport
import Timer
import TimerMock
import VPNSharedTesting

class AppSessionRefreshTimerTests: CaseIsolatedDatabaseTestCase {
    var alertService: CoreAlertServiceDummy!
    var propertiesManager: PropertiesManagerMock!
    var repositoryWrapper: ServerRepositoryWrapper!
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

    override func setUpWithError() throws {
        super.setUp()
        alertService = CoreAlertServiceDummy()
        propertiesManager = PropertiesManagerMock()
        networking = NetworkingMock()
        networkingDelegate = FullNetworkingMockDelegate()
        let initialServers = [testData.server1, testData.server2, testData.server3].map { VPNServer(legacyModel: $0) }
        try repository.upsert(servers: initialServers)
        repositoryWrapper = ServerRepositoryWrapper(repository: repository)

        networking.delegate = networkingDelegate
        vpnKeychain = VpnKeychainMock()
        authKeychain = MockAuthKeychain()
        apiService = VpnApiService(networking: networking, vpnKeychain: vpnKeychain, countryCodeProvider: CountryCodeProviderImplementation(), authKeychain: authKeychain)
        appSessionRefresher = withDependencies {
            $0.serverRepository = .wrapped(wrappedWith: repositoryWrapper)
        } operation: {
            return AppSessionRefresherMock(factory: self)
        }
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
        repositoryWrapper = nil
        networking = nil
        networkingDelegate = nil
        apiService = nil
        vpnKeychain = nil
        appSessionRefresher.didAttemptLogin = nil // Prevents crashes in other tests
        appSessionRefresher = nil
        timerFactory = nil
        appSessionRefreshTimer = nil
    }

    func checkForSuccessfulServerUpdate() throws {
        for serverUpdate in networkingDelegate.apiServerLoads {
            guard let server = try repositoryWrapper.getFirstServer(
                filteredBy: [.logicalID(serverUpdate.serverId)],
                orderedBy: .fastest
            ) else {
                XCTFail("Could not find server with id \(serverUpdate.serverId)")
                continue
            }

            XCTAssertEqual(server.logical.id, serverUpdate.serverId)
            XCTAssertEqual(server.logical.score, serverUpdate.score)
            XCTAssertEqual(server.logical.load, serverUpdate.load)
            XCTAssertEqual(server.logical.status, serverUpdate.status)
        }
    }

    func testRefreshTimer() throws { // swiftlint:disable:this function_body_length
        let expectations = (
            updateServers: (1...2).map { XCTestExpectation(description: "update server list #\($0)") },
            updateCredentials: XCTestExpectation(description: "update vpn credentials"),
            displayAlert: XCTestExpectation(description: "Alert displayed for old app version")
        )
        authKeychain.setMockUsername("user")

        var (nServerUpdates, nCredUpdates) = (0, 0)

        repositoryWrapper.didUpdateLoads = { _ in
            guard nServerUpdates < expectations.updateServers.count else {
                XCTFail("Index out of range")
                return
            }
            expectations.updateServers[nServerUpdates].fulfill()
            nServerUpdates += 1
        }

        vpnKeychain.didStoreCredentials = { _ in
            expectations.updateCredentials.fulfill()
            nCredUpdates += 1
        }

        alertService.alertAdded = { _ in
            expectations.displayAlert.fulfill()
        }

        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(planName: "plus",
                                                                           maxTier: .paidTier)

        appSessionRefresher.loggedIn = true
        appSessionRefreshTimer.startTimers()

        networkingDelegate.apiServerLoads = [
            .init(serverId: testData.server1.id, load: 10, score: 1.2345, status: 0),
            .init(serverId: testData.server2.id, load: 20, score: 2.3456, status: 1),
            .init(serverId: testData.server3.id, load: 30, score: 3.4567, status: 2),
        ]
        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(planName: "visionary",
                                                                           maxTier: .paidTier)
        timerFactory.runRepeatingTimers()
        wait(for: [expectations.updateServers[0], expectations.updateCredentials], timeout: 10)
        XCTAssertNotNil(vpnKeychain.credentials)
        XCTAssertEqual(vpnKeychain.credentials?.description, networkingDelegate.apiCredentials?.description)
        try checkForSuccessfulServerUpdate()

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
        try checkForSuccessfulServerUpdate()

        guard let alert = alertService.alerts.last as? AppUpdateRequiredAlert else {
            XCTFail("Displayed wrong kind of alert during app info refresh")
            return
        }

        XCTAssertEqual(alert.message, message, "Should have displayed alert returned from API")

        appSessionRefreshTimer.stopTimers()

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

extension AppSessionRefreshTimerTests: VpnApiServiceFactory, VpnKeychainFactory, PropertiesManagerFactory, CoreAlertServiceFactory, AppSessionRefresherFactory, TimerFactoryCreator {

    func makeTimerFactory() -> TimerFactory {
        return timerFactory
    }

    func makeCoreAlertService() -> CoreAlertService {
        return alertService
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
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
