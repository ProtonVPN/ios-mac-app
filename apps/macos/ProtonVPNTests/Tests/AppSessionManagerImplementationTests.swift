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

import Announcement
@testable import CommonNetworking
import CommonNetworkingTestSupport
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Localization
import Persistence
import PMLogger
import ProtonCoreNetworking
@testable import ProtonVPN
import VPNAppCore // UnauthKeychain
import VPNShared
import VPNSharedTesting

private func mockAuthCredentials(username: String) -> AuthCredentials {
    AuthCredentials(username: username, accessToken: "", refreshToken: "", sessionId: "", userId: "", scopes: [], mailboxPassword: "", isCredentialLess: false)
}

private var testAuthCredentials: AuthCredentials = mockAuthCredentials(username: "username")

private let subuserWithoutSessionsResponseError = ResponseError(
    httpCode: HttpStatusCode.accessForbidden.rawValue,
    responseCode: ApiErrorCode.subuserWithoutSessions,
    userFacingMessage: nil,
    underlyingError: nil
)

// We would like to use `TestIsolatedDatabaseTestCase` here, but Xcode fails to link `PersistenceTestSupport` correctly
final class AppSessionManagerImplementationTests: XCTestCase {
    fileprivate var alertService: AppSessionManagerAlertServiceMock!
    fileprivate var authKeychain: AuthKeychainHandleMock!
    fileprivate var unauthKeychain: UnauthKeychainMock!
    var networking: NetworkingMock!
    var networkingDelegate: FullNetworkingMockDelegate!
    var manager: AppSessionManagerImplementation!
    var vpnKeychain: VpnKeychainMock!
    var appStateManager: AppStateManagerMock!
    var repository: ServerRepository!
    var updateChecker: UpdateCheckerMock!

    let asyncTimeout: TimeInterval = 5

    override func invokeTest() {
        repository = withDependencies {
            $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral)
        } operation: {
            ServerRepository.liveValue
        }

        withDependencies {
            $0.serverRepository = repository
        } operation: {
            super.invokeTest()
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        networking = NetworkingMock()
        authKeychain = AuthKeychainHandleMock()
        unauthKeychain = UnauthKeychainMock()
        vpnKeychain = VpnKeychainMock()
        alertService = AppSessionManagerAlertServiceMock()
        appStateManager = AppStateManagerMock()
        updateChecker = UpdateCheckerMock()

        networkingDelegate = FullNetworkingMockDelegate()
        let freeCreds = VpnKeychainMock.vpnCredentials(planName: "free", maxTier: .freeTier)
        networkingDelegate.apiCredentials = freeCreds
        networking.delegate = networkingDelegate

        manager = withDependencies {
            $0.date = .constant(Date())
            $0.vpnApiClient.clientCredentials = { [weak self] in
                guard let self else {
                    throw NSError.testError()
                }
                guard let credentials = networkingDelegate.apiCredentials else {
                    throw NSError.testError()
                }
                return credentials
            }
            $0.vpnApiClient.loads = { _ in
                [:]
            }
            $0.vpnApiClient.virtualServices = {
                VPNStreamingResponse(code: 1, resourceBaseURL: "url", streamingServices: [:])
            }
            $0.vpnApiClient.userLocation = {
                nil
            }
            $0.vpnApiClient.refreshServerInfo = { _, _ in
                nil
            }
            $0.vpnApiClient.sessionsCount = {
                SessionsResponse(sessionCount: 1)
            }
        } operation: {
            let factory = ManagerFactoryMock(
                alertService: alertService,
                appStateManager: appStateManager,
                updateChecker: updateChecker
            )
            return AppSessionManagerImplementation(factory: factory)
        }
    }

    override func tearDown() {
        super.tearDown()
        alertService = nil
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
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests

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

    func testSuccessfulSilentLoginLogsIn() async throws {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out while logging in")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        authKeychain.credentials = testAuthCredentials

        try await manager.attemptSilentLogIn()
        XCTAssertTrue(manager.loggedIn)
    }

    func testSilentLoginWithMissingCredentialsFails() async throws {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out while logging in")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests

        do {
            try await manager.attemptSilentLogIn()
            XCTFail("Expected missing credentials error but got success")
        } catch {
            guard case CommonVpnError.userCredentialsMissing = error else {
                XCTFail("Expected missing credentials error but got \(error)")
                return
            }
            XCTAssertFalse(manager.loggedIn)
        }
    }

    func testLoginSubuserWithoutSessionsFails() throws {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out")
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        networkingDelegate.apiCredentialsResponseError = subuserWithoutSessionsResponseError
        authKeychain.username = "testUsername"
        manager.finishLogin(
            authCredentials: testAuthCredentials,
            success: {
                loginExpectation.fulfill()
                XCTFail("Expected \(CommonVpnError.subuserWithoutSessions) but sucessfully logged in instead.")
            },
            failure: { error in
                loginExpectation.fulfill()
                guard case CommonVpnError.subuserWithoutSessions = error else {
                    return XCTFail("Expected subuser without sessions error but got: \(error)")
                }
                XCTAssertFalse(self.manager.loggedIn, "Expected failure logging in, but loggedIn is true")
            }
        )

        wait(for: [loginExpectation], timeout: asyncTimeout)
    }

    func testLoginPostsSessionChangedNotification() async throws {
        let sessionChangedNotificationExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)

        try await login(with: testAuthCredentials)

        await fulfillment(of: [sessionChangedNotificationExpectation], timeout: asyncTimeout)
    }

    func testLoginDoesNotPostSessionChangedNotificationWhenAlreadyLoggedIn() throws {
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        authKeychain.credentials = testAuthCredentials
        manager.sessionStatus = .established

        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")

        assertNotPosted(SessionChanged.name, by: manager!) {
            Task {
                do {
                    try await manager.attemptSilentLogIn()
                    loginExpectation.fulfill()
                } catch {
                    XCTFail("Should succeed silently logging in when already logged in")
                }
            }

            wait(for: [loginExpectation], timeout: asyncTimeout)
        }
    }

    // MARK: Active VPN connection login tests

    func testConnectionDisconnectsWhenLoggingInDifferentUserAndAlertConfirmed() async throws {
        let activeSessionAlertExpectation = XCTestExpectation(description: "Active session alert should be shown")
        let differentUserServerDescriptor = ServerDescriptor(username: "Alice", address: "")
        appStateManager.state = .connected(differentUserServerDescriptor)
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        authKeychain.credentials = testAuthCredentials
        alertService.addAlertHandler(for: ActiveSessionWarningAlert.self, handler: { alert in
            activeSessionAlertExpectation.fulfill()
            alert.triggerHandler(forFirstActionOfType: .confirmative)
        })

        try await manager.attemptSilentLogIn()

        await fulfillment(of: [activeSessionAlertExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn)
        XCTAssertTrue(appStateManager.state.isDisconnected)
    }

    func testConnectionPersistsWhenLoggingInDifferentUserAndAlertCancelled() async throws {
        let activeSessionAlertExpectation = XCTestExpectation(description: "Active session alert should be shown")
        let differentUserServerDescriptor = ServerDescriptor(username: "Alice", address: "")
        appStateManager.state = .connected(differentUserServerDescriptor)
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        authKeychain.credentials = testAuthCredentials
        alertService.addAlertHandler(for: ActiveSessionWarningAlert.self, handler: { alert in
            activeSessionAlertExpectation.fulfill()
            alert.triggerHandler(forFirstActionOfType: .cancel)
        })

        try await manager.attemptSilentLogIn()

        await fulfillment(of: [activeSessionAlertExpectation], timeout: asyncTimeout)
        XCTAssertTrue(appStateManager.state.isConnected)
        XCTAssertFalse(manager.loggedIn)
    }

    func testConnectionPersistsWhenLoggingInSameUser() async throws {
        let loginExpectation = XCTestExpectation(description: "Manager should not time out when attempting a login")
        let sameUserServerDescriptor = ServerDescriptor(username: "username", address: "")
        appStateManager.state = .connected(sameUserServerDescriptor)
        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        authKeychain.credentials = testAuthCredentials

        try await manager.attemptSilentLogIn()

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

    func testNoAlertShownOnLogoutWhenNotDisconnected() async throws {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        try await login(with: testAuthCredentials)
        appStateManager.state = .disconnected

        manager.logOut() // logOut runs asynchronously but has no completion handler

        await fulfillment(of: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn)
    }

    func testLogoutShowsNoAlertWhenConnecting() async throws {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        try await login(with: testAuthCredentials)
        appStateManager.state = .connecting(ServerDescriptor(username: "", address: ""))

        manager.logOut() // logOut runs asynchronously but has no completion handler

        await fulfillment(of: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to cancel the active connection attempt")
    }

    func testLogoutShowsNoAlertWhenConnectedButForceIsTrue() async throws {
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        try await login(with: testAuthCredentials)
        appStateManager.state = .connected(.init(username: "", address: ""))

        manager.logOut(force: true, reason: "") // logOut runs asynchronously but has no completion handler

        await fulfillment(of: [logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to cancel the active connection attempt")
    }

    func testLogoutLogsOutWhenConnectedAndLogoutAlertConfirmed() async throws {
        let logoutAlertExpectation = XCTestExpectation(description: "Manager should not time out when attempting a logout")
        let logoutFinishExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)
        try await login(with: testAuthCredentials)
        appStateManager.state = .connected(.init(username: "", address: ""))
        alertService.addAlertHandler(for: LogoutWarningLongAlert.self, handler: { alert in
            alert.triggerHandler(forFirstActionOfType: .confirmative)
            logoutAlertExpectation.fulfill()
        })

        manager.logOut() // logOut runs asynchronously but has no completion handler

        await fulfillment(of: [logoutAlertExpectation, logoutFinishExpectation], timeout: asyncTimeout)
        XCTAssertFalse(manager.loggedIn, "Expected logOut to successfully log the user out")
        XCTAssertTrue(appStateManager.state.isDisconnected, "Expected logOut to disconnect the active connection")
    }

    func testLogoutCancelledWhenConnectedAndLogoutAlertCancelled() async throws {
        let logoutAlertExpectation = XCTestExpectation(description: "Manager should not time out when attempting a logout")
        try await login(with: testAuthCredentials)
        appStateManager.state = .connected(.init(username: "", address: ""))
        alertService.addAlertHandler(for: LogoutWarningLongAlert.self, handler: { alert in
            alert.triggerHandler(forFirstActionOfType: .cancel)
            logoutAlertExpectation.fulfill()
        })

        manager.logOut() // logOut runs asynchronously but has no completion handler

        await fulfillment(of: [logoutAlertExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn, "Expected logOut to be cancelled when the logout is not confirmed")
        XCTAssertTrue(appStateManager.state.isConnected, "Logout should not stop the active connection if cancelled")
    }

    // MARK: Helpers

    /// Convenience method for getting AppSessionManager into the logged in state
    func login(with authCredentials: AuthCredentials) async throws {
        let sessionChangedNotificationExpectation = XCTNSNotificationExpectation(name: SessionChanged.name, object: manager)

        networkingDelegate.apiVpnLocation = .mock
        networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        authKeychain.credentials = authCredentials

        try await manager.attemptSilentLogIn()

        await fulfillment(of: [sessionChangedNotificationExpectation], timeout: asyncTimeout)
        XCTAssertTrue(manager.loggedIn)
    }

    /// Invokes `XCTFail` if `notification` is posted any time during the execution of `operation`.
    /// This helper controls the lifetime of the notification subscription token while avoiding the 'unused variable`
    /// warning that would arise from assigning a notification token to a variable without accessing it.
    ///
    /// Can be moved to `ErgonomicsTestSupport` once app targets are able to link test support targets
    private func assertNotPosted<T>(
        _ notification: Notification.Name,
        by object: Any?,
        during operation: () -> T
    ) -> T {
        let subscribeAndReturnToken = {
            NotificationCenter.default.addObserver(for: notification, object: object) { notification in
                XCTFail("Unexpected notification posted: \(notification)")
            }
        }
        return withExtendedLifetime(subscribeAndReturnToken()) { _ in
            operation()
        }
    }
}

private class ManagerFactoryMock: AppSessionManagerImplementation.Factory {
    @Dependency(\.date) var date

    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private let alertService: CoreAlertService
    private let appStateManager: AppStateManager
    private let updateChecker: UpdateChecker

    let appCertificateRefreshManagerMock = AppCertificateRefreshManagerMock()
    let announcementRefresherMock = AnnouncementRefresherMock()
    let appSessionRefreshTimerMock = AppSessionRefreshTimerMock()

    let profileManager = ProfileManager(
        profileStorage: ProfileStorage()
    )

    func makeAppCertificateRefreshManager() -> AppCertificateRefreshManager { appCertificateRefreshManagerMock }
    func makeAnnouncementRefresher() -> AnnouncementRefresher { announcementRefresherMock }
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer { appSessionRefreshTimerMock }
    func makeAppStateManager() -> AppStateManager { appStateManager }
    func makeCoreAlertService() -> CoreAlertService { alertService }
    func makeProfileManager() -> ProfileManager { profileManager }
    func makeSystemExtensionManager() -> SystemExtensionManager { SystemExtensionManagerMock(factory: self) }
    func makeVpnAuthentication() -> VpnAuthentication { VpnAuthenticationMock() }
    func makeVpnGateway() -> VpnGatewayProtocol { VpnGatewayMock() }
    func makeNetworking() -> Networking { NetworkingMock() }
    func makeUpdateChecker() -> any UpdateChecker { updateChecker }

    init(
        alertService: CoreAlertService,
        appStateManager: AppStateManager,
        updateChecker: UpdateChecker
    ) {
        self.alertService = alertService
        self.appStateManager = appStateManager
        self.updateChecker = updateChecker
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

    func store(_ credentials: VPNShared.AuthCredentials, forContext _: AppContext?, source _: VPNShared.AuthCredentialsSource) throws {
        self.credentials = credentials
    }

    func fetch(forContext _: AppContext?) -> AuthCredentials? { credentials }
    func fetch(forContext _: AppContext?) throws -> AuthCredentials {
        guard let credentials else {
            throw KeychainError.credentialsMissing("test-auth-keychain-storage-key")
        }
        return credentials
    }

    func clear(_: VPNShared.ClearKeychainReason) {}
}

private class AppSessionManagerAlertServiceMock: CoreAlertService {
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

private extension SystemAlert {
    func triggerHandler(forFirstActionOfType type: PrimaryActionType) {
        actions.first { $0.style == type }?.handler?()
    }
}
