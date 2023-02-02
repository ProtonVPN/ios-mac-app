//
//  Created on 31/01/2023.
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

import XCTest
import vpncore
import VPNShared
import Dependencies
@testable import ProtonVPN

fileprivate let testData = MockTestData()
fileprivate let testDate = Date(timeIntervalSinceReferenceDate: 8000000000)
fileprivate let mockCredentials = AuthCredentials(username: "", accessToken: "", refreshToken: "", sessionId: "", userId: "", expiration: testDate, scopes: [])
fileprivate let vpnCredentials = VpnKeychainMock.vpnCredentials(accountPlan: .plus, maxTier: CoreAppConstants.VpnTiers.plus)
fileprivate let subuserCredentials = VpnCredentials(status: 0, expirationTime: testDate, accountPlan: .plus, maxConnect: 0, maxTier: 0, services: 0, groupId: "", name: "", password: "", delinquent: 0, credit: 0, currency: "", hasPaymentMethod: false, planName: nil, subscribed: nil)

final class AppSessionManagerImplementationTests: XCTestCase {

    var propertiesManager: PropertiesManagerMock!
    var serverStorage: ServerStorageMock!
    var networking: NetworkingMock!
    var networkingDelegate: FullNetworkingMockDelegate!
    var manager: AppSessionManagerImplementation!
    var authKeychain: AuthKeychainHandleMock!
    var vpnKeychain: VpnKeychainMock!
    var alertService: AppSessionManagerAlertServiceMock!
    var appStateManager: AppStateManagerMock!

    let asyncTimeout: TimeInterval = 1

    var mockVPNAPIService: VpnApiService {
        networking = NetworkingMock()
        networkingDelegate = FullNetworkingMockDelegate()
        networking.delegate = networkingDelegate

        return VpnApiService(
            networking: networking,
            vpnKeychain: VpnKeychainMock(),
            countryCodeProvider: CountryCodeProviderImplementation()
        )
    }

    override func setUp() {
        super.setUp()
        propertiesManager = PropertiesManagerMock()
        networking = NetworkingMock()
        networkingDelegate = FullNetworkingMockDelegate()
        networking.delegate = networkingDelegate
        authKeychain = AuthKeychainHandleMock()
        vpnKeychain = VpnKeychainMock()
        alertService = AppSessionManagerAlertServiceMock()
        appStateManager = AppStateManagerMock()

        manager = withDependencies {
            $0.date = .constant(Date())
        } operation: {
            let factory = ManagerFactoryMock(
                vpnAPIService: mockVPNAPIService,
                authKeychain: authKeychain,
                vpnKeychain: vpnKeychain,
                alertService: alertService,
                appStateManager: appStateManager
            )
            return AppSessionManagerImplementation(factory: factory)
        }
    }

    override func tearDown() {
        super.tearDown()
        alertService = nil
        propertiesManager = nil
        serverStorage = nil
        networking = nil
        networkingDelegate = nil
    }

    // MARK: Login tests

    func testLoggedInFalseBeforeLogin() throws {
        XCTAssertFalse(manager.loggedIn)
    }

    func testSuccessfulLoginWithAuthCredentialsLogsIn() throws {
        networkingDelegate.apiVpnLocation = testData.vpnLocation
        networkingDelegate.apiClientConfig = testData.defaultClientConfig

        let loginExpectation = XCTestExpectation(description: "Manager should not time out")
        manager.finishLogin(
            authCredentials: mockCredentials,
            success: {
                loginExpectation.fulfill()
                XCTAssertTrue(self.manager.loggedIn)
            },
            failure: { error in
                loginExpectation.fulfill()
                XCTFail("Expected successful login but got error: \(error)")
            }
        )

        wait(for: [loginExpectation], timeout: asyncTimeout)
    }

    func testSuccessfulSilentLoginLogsIn() throws {
        networkingDelegate.apiVpnLocation = testData.vpnLocation
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = mockCredentials

        let loginExpectation = XCTestExpectation(description: "Manager should not time out while logging in")
        manager.attemptSilentLogIn { result in
            loginExpectation.fulfill()

            guard case .success = result else {
                return XCTFail("Expected successful login but got: \(result)")
            }

            XCTAssertTrue(self.manager.loggedIn)
        }

        wait(for: [loginExpectation], timeout: asyncTimeout)
    }

    func testSilentLoginWithMissingCredentialsFails() throws {
        networkingDelegate.apiVpnLocation = testData.vpnLocation
        networkingDelegate.apiClientConfig = testData.defaultClientConfig

        let loginExpectation = XCTestExpectation(description: "Manager should not time out while logging in")
        manager.attemptSilentLogIn { result in
            loginExpectation.fulfill()

            guard case .failure(ProtonVpnError.userCredentialsMissing) = result else {
                return XCTFail("Expected missing credentials error but got: \(result)")
            }

            XCTAssertFalse(self.manager.loggedIn)
        }

        wait(for: [loginExpectation], timeout: asyncTimeout)
    }

    func testLoginSubuserWithoutSessionsFails() throws {
        networkingDelegate.apiVpnLocation = testData.vpnLocation
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        vpnKeychain.credentials = subuserCredentials
        XCTAssertTrue(try vpnKeychain.fetchCached().isSubuserWithoutSessions, "Expected cached credentials to represent subuser without sessions")

        let loginExpectation = XCTestExpectation(description: "Manager should not time out")
        manager.finishLogin(
            authCredentials: mockCredentials,
            success: {
                loginExpectation.fulfill()
                XCTFail("Expected \(ProtonVpnError.subuserWithoutSessions) but sucessfully logged in instead.")
            },
            failure: { error in
                loginExpectation.fulfill()
                guard case ProtonVpnError.subuserWithoutSessions = error else {
                    return XCTFail("Expected subuser without sessions error but got: \(error)")
                }
                XCTAssertFalse(self.manager.loggedIn, "Expected failure logging in, but loggedIn is true")
            }
        )

        wait(for: [loginExpectation], timeout: asyncTimeout)
    }

    // MARK: Logout tests

    func testNoAlertShownOnLogoutWhenNotLoggedIn() {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: manager.sessionChanged)
        alertService.logoutAlertAdded = { alert in
            XCTFail("Logout confirmation alert should not be displayed if the user is not logged in")
        }

        manager.logOut() // logOut runs asynchronously but has no completion handler
        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn)
    }

    func testNoAlertShownOnLogoutWhenNotDisconnected() {
        login()
        appStateManager.state = .disconnected

        let logoutFinishExpectation = XCTNSNotificationExpectation(name: manager.sessionChanged)
        alertService.logoutAlertAdded = { alert in
            XCTFail("Logout confirmation alert should not be displayed if the user is not logged in")
        }

        manager.logOut() // logOut runs asynchronously but has no completion handler
        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn)
    }

    func testLogoutShowsNoAlertWhenConnecting() {
        login()

        let logoutFinishExpectation = XCTNSNotificationExpectation(name: manager.sessionChanged)
        appStateManager.state = .connecting(ServerDescriptor(username: "", address: ""))

        alertService.logoutAlertAdded = { alert in
            XCTFail("Logout confirmation alert should not be displayed if there is no active connection")
        }
        manager.logOut() // logOut runs asynchronously but has no completion handler
        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to cancel the active connection attempt")
    }

    func testLogoutLogsOutWhenConnectedAndLogoutAlertConfirmed() {
        login()

        let logoutAlertExpectation = XCTestExpectation(description: "Manager should not time out when attempting a logout")
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: manager.sessionChanged)
        appStateManager.state = .connected(.init(username: "", address: ""))

        alertService.logoutAlertAdded = { alert in
            alert.triggerHandler(forFirstActionOfType: .confirmative)
            logoutAlertExpectation.fulfill()
        }
        manager.logOut() // logOut runs asynchronously but has no completion handler
        wait(for: [logoutAlertExpectation, logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to disconnect the active connection")
    }

    func testLogoutCancelledWhenConnectedAndLogoutAlertCancelled() {
        login()
        appStateManager.state = .connected(.init(username: "", address: ""))

        let logoutAlertExpectation = XCTestExpectation(description: "Manager should not time out when attempting a logout")

        alertService.logoutAlertAdded = { alert in
            alert.triggerHandler(forFirstActionOfType: .cancel)
            logoutAlertExpectation.fulfill()
        }
        manager.logOut() // logOut runs asynchronously but has no completion handler
        wait(for: [logoutAlertExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn, "Expected logOut to be cancelled when the logout is not confirmed")
        XCTAssertTrue(appStateManager.state.isConnected, "Logout should not stop the active connection if cancelled")
    }

    // MARK: Helpers

    /// Convenience method for getting AppSessionManager into the logged in state
    func login() {
        networkingDelegate.apiVpnLocation = testData.vpnLocation
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = mockCredentials
        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")

        manager.attemptSilentLogIn(completion: { _ in loginExpectation.fulfill() })
        wait(for: [loginExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn)
    }
}

class ManagerFactoryMock: AppSessionManagerImplementation.Factory {

    @Dependency(\.date) var clock

    private let container = DependencyContainer()
    private let vpnAPIService: VpnApiService
    private let authKeychain: AuthKeychainHandle
    private let vpnKeychain: VpnKeychainProtocol
    private let alertService: CoreAlertService
    private let appStateManager: AppStateManager

    func makeNavigationService() -> NavigationService { NavigationServiceMock(container) }
    func makePlanService() -> PlanService { PlanServiceMock() }
    func makeAuthKeychainHandle() -> AuthKeychainHandle { authKeychain }
    func makeAppCertificateRefreshManager() -> AppCertificateRefreshManager { container.makeAppCertificateRefreshManager() }
    func makeAnnouncementRefresher() -> AnnouncementRefresher { container.makeAnnouncementRefresher() }
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer { container.makeAppSessionRefreshTimer() }
    func makeAppStateManager() -> AppStateManager { appStateManager }
    func makeCoreAlertService() -> CoreAlertService { alertService }
    func makeProfileManager() -> ProfileManager { container.makeProfileManager() }
    func makePropertiesManager() -> PropertiesManagerProtocol { PropertiesManagerMock() }
    func makeServerStorage() -> ServerStorage { ServerStorageMock() }
    func makeSystemExtensionManager() -> SystemExtensionManager { SystemExtensionManagerMock(factory: container) }
    func makeVpnAuthentication() -> VpnAuthentication { VpnAuthenticationMock() }
    func makeVpnGateway() -> VpnGatewayProtocol { VpnGatewayMock() }
    func makeVpnKeychain() -> VpnKeychainProtocol { vpnKeychain }
    func makeVpnApiService() -> vpncore.VpnApiService { vpnAPIService }

    init(
        vpnAPIService: VpnApiService,
        authKeychain: AuthKeychainHandle,
        vpnKeychain: VpnKeychainProtocol,
        alertService: CoreAlertService,
        appStateManager: AppStateManager
    ) {
        self.vpnAPIService = vpnAPIService
        self.authKeychain = authKeychain
        self.vpnKeychain = vpnKeychain
        self.alertService = alertService
        self.appStateManager = appStateManager
    }

}

class AuthKeychainHandleMock: AuthKeychainHandle {
    var credentials: AuthCredentials?

    func store(_ credentials: VPNShared.AuthCredentials, forContext: VPNShared.AppContext?) throws { }
    func fetch(forContext: AppContext?) -> AuthCredentials? { return credentials }
    func clear() { }
}

class AppSessionManagerAlertServiceMock: CoreAlertService {
    var logoutAlertAdded: ((LogoutWarningLongAlert) -> Void)?

    init() {}

    func push(alert: SystemAlert) {
        if let logoutAlert = alert as? LogoutWarningLongAlert {
            logoutAlertAdded?(logoutAlert)
        }
    }
}

private extension SystemAlert {
    func triggerHandler(forFirstActionOfType type: PrimaryActionType) {
        actions.first { $0.style == type }?.handler?()
    }
}

class NavigationServiceMock: NavigationService {
    override func sessionRefreshed() { }
}
