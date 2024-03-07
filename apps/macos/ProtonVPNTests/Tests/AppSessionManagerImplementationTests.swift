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
import LegacyCommon

import VPNShared
import Dependencies
import VPNSharedTesting
import ProtonCoreNetworking
@testable import ProtonVPN

fileprivate let testData = MockTestData()
fileprivate func mockAuthCredentials(username: String) -> AuthCredentials {
    return AuthCredentials(username: username, accessToken: "", refreshToken: "", sessionId: "", userId: "", scopes: [])
}
fileprivate var testAuthCredentials: AuthCredentials = mockAuthCredentials(username: "username")

fileprivate let subuserWithoutSessionsResponseError = ResponseError(httpCode: HttpStatusCode.accessForbidden,
                                                                    responseCode: ApiErrorCode.subuserWithoutSessions,
                                                                    userFacingMessage: nil,
                                                                    underlyingError: nil)

final class AppSessionManagerImplementationTests: XCTestCase {

    fileprivate var alertService: AppSessionManagerAlertServiceMock!
    fileprivate var authKeychain: AuthKeychainHandleMock!
    fileprivate var unauthKeychain: UnauthKeychainMock!
    var propertiesManager: PropertiesManagerMock!
    var serverStorage: ServerStorageMock!
    var networking: NetworkingMock!
    var networkingDelegate: FullNetworkingMockDelegate!
    var manager: AppSessionManagerImplementation!
    var vpnKeychain: VpnKeychainMock!
    var appStateManager: AppStateManagerMock!

    let asyncTimeout: TimeInterval = 5

    override func setUp() {
        super.setUp()
        propertiesManager = PropertiesManagerMock()
        networking = NetworkingMock()
        authKeychain = AuthKeychainHandleMock()
        unauthKeychain = UnauthKeychainMock()
        vpnKeychain = VpnKeychainMock()
        alertService = AppSessionManagerAlertServiceMock()
        appStateManager = AppStateManagerMock()


        networkingDelegate = FullNetworkingMockDelegate()
        let freeCreds = VpnKeychainMock.vpnCredentials(planName: "free", maxTier: CoreAppConstants.VpnTiers.free)
        networkingDelegate.apiCredentials = freeCreds
        networking.delegate = networkingDelegate

        let mockAPIService = VpnApiService(
            networking: networking,
            vpnKeychain: VpnKeychainMock(),
            countryCodeProvider: CountryCodeProviderImplementation(),
            authKeychain: authKeychain
        )

        manager = withDependencies {
            $0.date = .constant(Date())
        } operation: {
            let factory = ManagerFactoryMock(
                vpnAPIService: mockAPIService,
                authKeychain: authKeychain,
                unauthKeychain: unauthKeychain,
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

    // MARK: Basic login tests

    func testLoggedInFalseBeforeLogin() throws {
        XCTAssertFalse(manager.loggedIn)
    }

    func testSuccessfulLoginWithAuthCredentialsLogsIn() throws {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig

        manager.finishLogin(
            authCredentials: mockAuthCredentials(username: "bob"),
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

        XCTAssertEqual(authKeychain.username, "bob", "Username should have been updated in auth keychain")
    }

    func testSuccessfulSilentLoginLogsIn() throws {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out while logging in")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = testAuthCredentials

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
        let loginExpectation = XCTestExpectation(description: "Manager should not time out while logging in")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig

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
        let loginExpectation = XCTestExpectation(description: "Manager should not time out")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        networkingDelegate.apiCredentialsResponseError = subuserWithoutSessionsResponseError
        authKeychain.username = "testUsername"
        manager.finishLogin(
            authCredentials: testAuthCredentials,
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

    func testLoginPostsSessionChangedNotification() throws {
        let sessionChangedNotificationExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)

        login(with: testAuthCredentials)

        wait(for: [sessionChangedNotificationExpectation], timeout: asyncTimeout)
    }

    func testLoginDoesNotPostSessionChangedNotificationWhenAlreadyLoggedIn() throws {
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = testAuthCredentials
        manager.sessionStatus = .established

        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")
        let sessionChangedNotificationExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        sessionChangedNotificationExpectation.isInverted = true

        manager.attemptSilentLogIn { result in
            loginExpectation.fulfill()
            guard case .success = result else { return XCTFail("Should succeed silently logging in when already logged in") }
        }

        wait(for: [loginExpectation, sessionChangedNotificationExpectation], timeout: asyncTimeout)
    }

    // MARK: Active VPN connection login tests

    func testConnectionDisconnectsWhenLoggingInDifferentUserAndAlertConfirmed() {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")
        let activeSessionAlertExpectation = XCTestExpectation(description: "Active session alert should be shown")
        let differentUserServerDescriptor = ServerDescriptor(username: "Alice", address: "")
        appStateManager.state = .connected(differentUserServerDescriptor)
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = testAuthCredentials
        alertService.addAlertHandler(for: ActiveSessionWarningAlert.self, handler: { alert in
            activeSessionAlertExpectation.fulfill()
            alert.triggerHandler(forFirstActionOfType: .confirmative)
        })

        manager.attemptSilentLogIn(completion: { result in
            loginExpectation.fulfill()
            guard case .success = result else { return XCTFail("Expected success logging in, but got: \(result)") }
        })

        wait(for: [activeSessionAlertExpectation, loginExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn)
        XCTAssertTrue(appStateManager.state.isDisconnected)
    }

    func testConnectionPersistsWhenLoggingInDifferentUserAndAlertCancelled() {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")
        let activeSessionAlertExpectation = XCTestExpectation(description: "Active session alert should be shown")
        let differentUserServerDescriptor = ServerDescriptor(username: "Alice", address: "")
        appStateManager.state = .connected(differentUserServerDescriptor)
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = testAuthCredentials
        alertService.addAlertHandler(for: ActiveSessionWarningAlert.self, handler: { alert in
            activeSessionAlertExpectation.fulfill()
            alert.triggerHandler(forFirstActionOfType: .cancel)
        })

        manager.attemptSilentLogIn(completion: { result in
            loginExpectation.fulfill()
            guard case .failure(ProtonVpnError.vpnSessionInProgress) = result else {
                return XCTFail("Expected success logging in, but got: \(result)")
            }
        })

        wait(for: [activeSessionAlertExpectation], timeout: asyncTimeout)
        XCTAssertTrue(appStateManager.state.isConnected)
        XCTAssertFalse(manager.loggedIn)
    }

    func testConnectionPersistsWhenLoggingInSameUser() {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")
        let sameUserServerDescriptor = ServerDescriptor(username: "username", address: "")
        appStateManager.state = .connected(sameUserServerDescriptor)
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = testAuthCredentials

        manager.attemptSilentLogIn(completion: { result in
            loginExpectation.fulfill()
            guard case .success = result else { return XCTFail("Expected success logging in, but got: \(result)") }
        })

        wait(for: [loginExpectation], timeout: asyncTimeout)
        XCTAssertTrue(appStateManager.state.isConnected)
        XCTAssertTrue(manager.loggedIn)
    }

    // MARK: Logout tests

    func testNoAlertShownOnLogoutWhenNotLoggedIn() {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)

        manager.logOut() // logOut runs asynchronously but has no completion handler

        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn)
    }

    func testNoAlertShownOnLogoutWhenNotDisconnected() {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        login(with: testAuthCredentials)
        appStateManager.state = .disconnected

        manager.logOut() // logOut runs asynchronously but has no completion handler

        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn)
    }

    func testLogoutShowsNoAlertWhenConnecting() {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        login(with: testAuthCredentials)
        appStateManager.state = .connecting(ServerDescriptor(username: "", address: ""))

        manager.logOut() // logOut runs asynchronously but has no completion handler

        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to cancel the active connection attempt")
    }

    func testLogoutShowsNoAlertWhenConnectedButForceIsTrue() {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        login(with: testAuthCredentials)
        appStateManager.state = .connected(.init(username: "", address: ""))

        manager.logOut(force: true, reason: "") // logOut runs asynchronously but has no completion handler

        wait(for: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to cancel the active connection attempt")
    }

    func testLogoutLogsOutWhenConnectedAndLogoutAlertConfirmed() {
        let logoutAlertExpectation = XCTestExpectation(description: "Manager should not time out when attempting a logout")
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        login(with: testAuthCredentials)
        appStateManager.state = .connected(.init(username: "", address: ""))
        alertService.addAlertHandler(for: LogoutWarningLongAlert.self, handler: { alert in
            alert.triggerHandler(forFirstActionOfType: .confirmative)
            logoutAlertExpectation.fulfill()
        })

        manager.logOut() // logOut runs asynchronously but has no completion handler

        wait(for: [logoutAlertExpectation, logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to disconnect the active connection")
    }

    func testLogoutCancelledWhenConnectedAndLogoutAlertCancelled() {
        let logoutAlertExpectation = XCTestExpectation(description: "Manager should not time out when attempting a logout")
        login(with: testAuthCredentials)
        appStateManager.state = .connected(.init(username: "", address: ""))
        alertService.addAlertHandler(for: LogoutWarningLongAlert.self, handler: { alert in
            alert.triggerHandler(forFirstActionOfType: .cancel)
            logoutAlertExpectation.fulfill()
        })

        manager.logOut() // logOut runs asynchronously but has no completion handler

        wait(for: [logoutAlertExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn, "Expected logOut to be cancelled when the logout is not confirmed")
        XCTAssertTrue(appStateManager.state.isConnected, "Logout should not stop the active connection if cancelled")
    }

    // MARK: Helpers

    /// Convenience method for getting AppSessionManager into the logged in state
    func login(with authCredentials: AuthCredentials) {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")
        let sessionChangedNotificationExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)

        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = testData.defaultClientConfig
        authKeychain.credentials = authCredentials

        manager.attemptSilentLogIn { _ in loginExpectation.fulfill() }

        wait(for: [loginExpectation, sessionChangedNotificationExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn)
    }
}

fileprivate let propertiesManagerMock = PropertiesManagerMock()

fileprivate class ManagerFactoryMock: AppSessionManagerImplementation.Factory {

    @Dependency(\.date) var date

    private let vpnAPIService: VpnApiService
    private let authKeychain: AuthKeychainHandle
    private let unauthKeychain: UnauthKeychainHandle
    private let vpnKeychain: VpnKeychainProtocol
    private let alertService: CoreAlertService
    private let appStateManager: AppStateManager

    let appCertificateRefreshManagerMock = AppCertificateRefreshManagerMock()
    let announcementRefresherMock = AnnouncementRefresherMock()
    let appSessionRefreshTimerMock = AppSessionRefreshTimerMock()

    let profileManager = ProfileManager(
        serverStorage: ServerStorageMock(),
        propertiesManager: propertiesManagerMock,
        profileStorage: ProfileStorage(authKeychain: MockAuthKeychain())
    )

    func makePlanService() -> PlanService { PlanServiceMock() }
    func makeAuthKeychainHandle() -> AuthKeychainHandle { authKeychain }
    func makeUnauthKeychainHandle() -> UnauthKeychainHandle { unauthKeychain }
    func makeAppCertificateRefreshManager() -> AppCertificateRefreshManager { appCertificateRefreshManagerMock }
    func makeAnnouncementRefresher() -> AnnouncementRefresher { announcementRefresherMock }
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer { appSessionRefreshTimerMock }
    func makeAppStateManager() -> AppStateManager { appStateManager }
    func makeCoreAlertService() -> CoreAlertService { alertService }
    func makeProfileManager() -> ProfileManager { profileManager }
    func makePropertiesManager() -> PropertiesManagerProtocol { propertiesManagerMock }
    func makeServerStorage() -> ServerStorage { ServerStorageMock() }
    func makeSystemExtensionManager() -> SystemExtensionManager { SystemExtensionManagerMock(factory: self) }
    func makeVpnAuthentication() -> VpnAuthentication { VpnAuthenticationMock() }
    func makeVpnGateway() -> VpnGatewayProtocol { VpnGatewayMock() }
    func makeVpnKeychain() -> VpnKeychainProtocol { vpnKeychain }
    func makeVpnApiService() -> LegacyCommon.VpnApiService { vpnAPIService }
    func makeNetworking() -> Networking { NetworkingMock() }

    init(
        vpnAPIService: VpnApiService,
        authKeychain: AuthKeychainHandle,
        unauthKeychain: UnauthKeychainHandle,
        vpnKeychain: VpnKeychainProtocol,
        alertService: CoreAlertService,
        appStateManager: AppStateManager
    ) {
        self.vpnAPIService = vpnAPIService
        self.authKeychain = authKeychain
        self.unauthKeychain = unauthKeychain
        self.vpnKeychain = vpnKeychain
        self.alertService = alertService
        self.appStateManager = appStateManager
    }

}

class AuthKeychainHandleMock: AuthKeychainHandle {
    var credentials: AuthCredentials? {
        didSet {
            username = credentials?.username
            userId = credentials?.userId
        }
    }
    var username: String?
    var userId: String?

    func saveToCache(_ credentials: VPNShared.AuthCredentials?) {
        self.credentials = credentials
    }
    func store(_ credentials: VPNShared.AuthCredentials, forContext: VPNShared.AppContext?) throws {
        self.credentials = credentials
    }
    func fetch(forContext: AppContext?) -> AuthCredentials? { return credentials }
    func clear() { }
}

fileprivate class AppSessionManagerAlertServiceMock: CoreAlertService {
    private var alertHandlers: [(alertType: SystemAlert.Type, handler: (SystemAlert) -> Void)] = []

    init() {}

    func addAlertHandler(for alertType: SystemAlert.Type, handler: @escaping (SystemAlert) -> Void) {
        alertHandlers.append((alertType, handler))
    }

    func push(alert: SystemAlert) {
        guard let alertHandler = alertHandlers.first(where: { type(of: alert) == $0.alertType }) else {
            return XCTFail("Unexpected alert was shown: \(alert)")
        }
        alertHandler.handler(alert)
    }
}

fileprivate extension SystemAlert {
    func triggerHandler(forFirstActionOfType type: PrimaryActionType) {
        actions.first { $0.style == type }?.handler?()
    }
}
