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

import Announcement
@testable import CommonNetworking
import CommonNetworkingTestSupport
import Connection
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Localization
import Persistence
import PMLogger
import ProtonCoreNetworking
@testable import ProtonVPN
import Sharing
import Testing
import VPNAppCore // UnauthKeychain
import VPNShared
import VPNSharedTesting

private func mockAuthCredentials(username: String) -> AuthCredentials {
    AuthCredentials(username: username, accessToken: "", refreshToken: "", sessionId: "", userId: "", scopes: [], mailboxPassword: "", isCredentialLess: false)
}

private func testAuthCredentials() -> AuthCredentials {
    mockAuthCredentials(username: "username")
}

private let subuserWithoutSessionsResponseError = ResponseError(
    httpCode: HttpStatusCode.accessForbidden.rawValue,
    responseCode: ApiErrorCode.subuserWithoutSessions,
    userFacingMessage: nil,
    underlyingError: nil
)

@Suite(.serialized)
@MainActor
struct AppSessionManagerImplementationTests {
    private let asyncTimeout: Duration = .seconds(5)

    final class TestContext {
        fileprivate let alertService: AppSessionManagerAlertServiceMock
        let authKeychain: AuthKeychainHandleMock
        let unauthKeychain: UnauthKeychainMock
        let networking: NetworkingMock
        let networkingDelegate: FullNetworkingMockDelegate
        let manager: AppSessionManagerImplementation
        let vpnKeychain: VpnKeychainMock
        let repository: ServerRepository
        let updateChecker: UpdateCheckerMock

        fileprivate init(
            alertService: AppSessionManagerAlertServiceMock,
            authKeychain: AuthKeychainHandleMock,
            unauthKeychain: UnauthKeychainMock,
            networking: NetworkingMock,
            networkingDelegate: FullNetworkingMockDelegate,
            manager: AppSessionManagerImplementation,
            vpnKeychain: VpnKeychainMock,
            repository: ServerRepository,
            updateChecker: UpdateCheckerMock
        ) {
            self.alertService = alertService
            self.authKeychain = authKeychain
            self.unauthKeychain = unauthKeychain
            self.networking = networking
            self.networkingDelegate = networkingDelegate
            self.manager = manager
            self.vpnKeychain = vpnKeychain
            self.repository = repository
            self.updateChecker = updateChecker
        }
    }

    // MARK: Basic login tests

    @Test
    func loggedInFalseBeforeLogin() async {
        await withTestContext { context in
            #expect(context.manager.loggedIn == false)
        }
    }

    @Test
    func successfulLoginWithAuthCredentialsLogsIn() async throws {
        try await withTestContext { context in
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests

            try await finishLogin(
                manager: context.manager,
                authCredentials: mockAuthCredentials(username: "bob")
            )

            #expect(context.manager.loggedIn)
            #expect(context.authKeychain.username == "bob")
        }
    }

    @Test
    func successfulSilentLoginLogsIn() async throws {
        try await withTestContext { context in
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.authKeychain.credentials = testAuthCredentials()

            try await context.manager.attemptSilentLogIn()
            #expect(context.manager.loggedIn)
        }
    }

    @Test
    func silentLoginWithMissingCredentialsFails() async {
        await withTestContext { context in
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests

            do {
                try await context.manager.attemptSilentLogIn()
                Issue.record("Expected missing credentials error but got success")
            } catch {
                guard case CommonVpnError.userCredentialsMissing = error else {
                    Issue.record("Expected missing credentials error but got \(error)")
                    return
                }
                #expect(context.manager.loggedIn == false)
            }
        }
    }

    @Test
    func loginSubuserWithoutSessionsFails() async {
        await withTestContext { context in
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.networkingDelegate.apiCredentialsResponseError = subuserWithoutSessionsResponseError
            context.authKeychain.username = "testUsername"

            do {
                try await finishLogin(
                    manager: context.manager,
                    authCredentials: testAuthCredentials()
                )
                Issue.record("Expected \(CommonVpnError.subuserWithoutSessions) but successfully logged in instead.")
            } catch {
                guard case CommonVpnError.subuserWithoutSessions = error else {
                    Issue.record("Expected subuser without sessions error but got: \(error)")
                    return
                }
                #expect(context.manager.loggedIn == false)
            }
        }
    }

    @Test
    func loginPostsSessionChangedNotification() async throws {
        try await withTestContext { context in
            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            try await login(with: testAuthCredentials(), context: context)
            let posted = await waitForTask(notificationTask, timeout: asyncTimeout) ?? false
            #expect(posted)
        }
    }

    @Test
    func loginDoesNotPostSessionChangedNotificationWhenAlreadyLoggedIn() async throws {
        try await withTestContext { context in
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.authKeychain.credentials = testAuthCredentials()
            context.manager.sessionStatus = .established

            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            try await context.manager.attemptSilentLogIn()
            let posted = await waitForTask(notificationTask, timeout: .milliseconds(300)) ?? false

            #expect(posted == false)
        }
    }

    // MARK: Active VPN connection login tests

    @Test
    func connectionDisconnectsWhenLoggingInDifferentUserAndAlertConfirmed() async throws {
        try await withTestContext { context in
            setConnectedStatus()
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.authKeychain.credentials = testAuthCredentials()

            try await context.manager.attemptSilentLogIn()

            #expect(context.manager.loggedIn)
            assertConnectedStatus()
        }
    }

    @Test
    func connectionPersistsWhenLoggingInDifferentUserAndAlertCancelled() async throws {
        try await withTestContext { context in
            setConnectedStatus()
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.authKeychain.credentials = testAuthCredentials()

            try await context.manager.attemptSilentLogIn()

            assertConnectedStatus()
            #expect(context.manager.loggedIn)
        }
    }

    @Test
    func connectionPersistsWhenLoggingInSameUser() async throws {
        try await withTestContext { context in
            setConnectedStatus()
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.authKeychain.credentials = testAuthCredentials()

            try await context.manager.attemptSilentLogIn()

            assertConnectedStatus()
            #expect(context.manager.loggedIn)
        }
    }

    // MARK: Logout tests

    @Test
    func noAlertShownOnLogoutWhenNotLoggedIn() async {
        await withTestContext { context in
            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            context.manager.logOut() // no-op in this state
            let posted = await waitForTask(notificationTask, timeout: .milliseconds(300)) ?? false
            #expect(posted == false)
            #expect(context.manager.loggedIn == false)
        }
    }

    @Test
    func noAlertShownOnLogoutWhenNotDisconnected() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectionStatus(vpnStatus: .disconnected, connectionState: .disconnected)

            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            context.manager.logOut()
            let posted = await waitForTask(notificationTask, timeout: asyncTimeout) ?? false
            #expect(posted)
            #expect(context.manager.loggedIn == false)
        }
    }

    @Test
    func logoutShowsNoAlertWhenConnecting() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectionStatus(vpnStatus: .connecting(.defaultFastest, nil), connectionState: .resolving)

            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            context.manager.logOut()
            let posted = await waitForTask(notificationTask, timeout: asyncTimeout) ?? false

            #expect(posted)
            #expect(context.manager.loggedIn == false)
            assertDisconnectedStatus()
        }
    }

    @Test
    func logoutShowsNoAlertWhenConnectedButForceIsTrue() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectedStatus()

            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            context.manager.logOut(force: true, reason: "")
            let posted = await waitForTask(notificationTask, timeout: asyncTimeout) ?? false

            #expect(posted)
            #expect(context.manager.loggedIn == false)
            assertDisconnectedStatus()
        }
    }

    @Test
    func logoutLogsOutWhenConnectedAndLogoutAlertConfirmed() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectedStatus()

            context.alertService.addAlertHandler(for: LogoutWarningLongAlert.self, handler: { alert in
                alert.triggerHandler(forFirstActionOfType: .confirmative)
            })

            let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)
            context.manager.logOut()
            let posted = await waitForTask(notificationTask, timeout: asyncTimeout) ?? false

            #expect(posted)
            #expect(context.manager.loggedIn == false)
            assertDisconnectedStatus()
        }
    }

    @Test
    func logoutCancelledWhenConnectedAndLogoutAlertCancelled() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectedStatus()
            context.alertService.addAlertHandler(for: LogoutWarningLongAlert.self, handler: { alert in
                alert.triggerHandler(forFirstActionOfType: .cancel)
            })

            context.manager.logOut()

            #expect(context.manager.loggedIn)
            assertConnectedStatus()
        }
    }

    // MARK: Helpers

    private func withTestContext(
        _ body: @escaping @MainActor (TestContext) async throws -> Void
    ) async rethrows {
        let repository = withDependencies {
            $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral)
        } operation: {
            ServerRepositoryKey.liveValue
        }

        let networking = NetworkingMock()
        let authKeychain = AuthKeychainHandleMock()
        let unauthKeychain = UnauthKeychainMock()
        let vpnKeychain = VpnKeychainMock()
        let alertService = AppSessionManagerAlertServiceMock()
        let updateChecker = UpdateCheckerMock()

        let networkingDelegate = FullNetworkingMockDelegate()
        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(planName: "free", maxTier: .freeTier)
        networking.delegate = networkingDelegate
        let networkingWrapper = CoreNetworkingWrapper(wrapped: networking)

        let factory = ManagerFactoryMock(
            alertService: alertService,
            updateChecker: updateChecker
        )

        try await withDependencies {
            $0.serverRepository = repository
            $0.date = .constant(Date())
            $0.networking = networkingWrapper
            $0.authKeychain = authKeychain
            $0.unauthKeychain = unauthKeychain
            $0.vpnKeychain = vpnKeychain
            $0.announcementRefresher = factory.announcementRefresherMock
            $0.connectionCommandClient = .init(
                send: { command in
                    guard case let .disconnect(_, completion) = command else { return }
                    @Shared(.vpnConnectionStatus) var vpnConnectionStatus
                    @Shared(.connectionState) var connectionState
                    $vpnConnectionStatus.withLock { $0 = .disconnected }
                    $connectionState.withLock { $0 = .disconnected }
                    Task { @MainActor in completion?() }
                },
                stream: { .finished }
            )
            $0.vpnApiClient.clientCredentials = {
                guard let credentials = networkingDelegate.apiCredentials else {
                    throw NSError.testError()
                }
                return credentials
            }
            $0.vpnApiClient.vpnProperties = { _, _, _ in
                if networkingDelegate.apiCredentialsResponseError?.responseCode == ApiErrorCode.subuserWithoutSessions {
                    throw CommonVpnError.subuserWithoutSessions
                }
                guard let credentials = networkingDelegate.apiCredentials else {
                    throw NSError.testError()
                }
                return VpnProperties(
                    serverInfo: .modified(at: nil, servers: [], freeServersOnly: false),
                    streamingServices: VPNStreamingResponse(code: 1, resourceBaseURL: "url", streamingServices: [:]),
                    vpnCredentials: credentials,
                    location: nil,
                    clientConfig: networkingDelegate.apiClientConfig ?? ClientConfig.defaultClientConfigForTests,
                    user: nil,
                    addresses: nil
                )
            }
            $0.vpnApiClient.loads = { _ in [:] }
            $0.vpnApiClient.virtualServices = { VPNStreamingResponse(code: 1, resourceBaseURL: "url", streamingServices: [:]) }
            $0.vpnApiClient.userLocation = { nil }
            $0.vpnApiClient.refreshServerInfo = { _, _ in nil }
            $0.vpnApiClient.sessionsCount = { SessionsResponse(sessionCount: 1) }
        } operation: {
            let manager = AppSessionManagerImplementation(factory: factory)
            let context = TestContext(
                alertService: alertService,
                authKeychain: authKeychain,
                unauthKeychain: unauthKeychain,
                networking: networking,
                networkingDelegate: networkingDelegate,
                manager: manager,
                vpnKeychain: vpnKeychain,
                repository: repository,
                updateChecker: updateChecker
            )

            setConnectionStatus(
                vpnStatus: .disconnected,
                connectionState: .disconnected
            )
            try await body(context)
        }
    }

    private func login(with authCredentials: AuthCredentials, context: TestContext) async throws {
        let notificationTask = makeNotificationTask(name: SessionChanged.name, object: context.manager)

        context.networkingDelegate.apiVpnLocation = .mock
        context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        context.authKeychain.credentials = authCredentials

        try await context.manager.attemptSilentLogIn()

        let posted = await waitForTask(notificationTask, timeout: asyncTimeout) ?? false
        #expect(posted)
        #expect(context.manager.loggedIn)
    }

    private func finishLogin(
        manager: AppSessionManagerImplementation,
        authCredentials: AuthCredentials
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.finishLogin(
                authCredentials: authCredentials,
                success: {
                    continuation.resume(returning: ())
                },
                failure: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }

    private func makeNotificationTask(name: Notification.Name, object: AnyObject?) -> Task<Bool, Never> {
        Task {
            for await _ in NotificationCenter.default.notifications(named: name, object: object) {
                return true
            }
            return false
        }
    }

    private func waitForTask<T: Sendable>(_ task: Task<T, Never>, timeout: Duration) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await task.value }
            group.addTask {
                try? await Task.sleep(for: timeout)
                task.cancel()
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func setConnectionStatus(vpnStatus: VPNConnectionStatus, connectionState: ConnectionState) {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus
        @Shared(.connectionState) var sharedConnectionState
        $vpnConnectionStatus.withLock { $0 = vpnStatus }
        $sharedConnectionState.withLock { $0 = connectionState }
    }

    private func setConnectedStatus() {
        let server = Server.mock()
        let wireGuardSettings = WireGuardSettings(
            backend: .go,
            transport: .udp,
            ports: [443],
            features: TunnelFeatures(killSwitch: false, excludeLocalNetworks: false)
        )
        let connectionFeatures = VPNConnectionFeatures(
            netshield: .off,
            vpnAccelerator: false,
            bouncing: nil,
            natType: .moderateNAT,
            safeMode: false,
            portForwarding: false
        )
        let intent = ServerConnectionIntent(
            spec: .defaultFastest,
            server: server,
            protocolConfiguration: .wireGuard(wireGuardSettings),
            features: connectionFeatures
        )
        let actual = VPNConnectionActual(server: server, intent: intent, connectedDate: Date())
        setConnectionStatus(
            vpnStatus: .connected(.defaultFastest, actual),
            connectionState: .connected(intent, server, Date(), nil)
        )
    }

    private func assertConnectedStatus(_ message: String = "Expected connection status to be connected") {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus
        if case .connected = vpnConnectionStatus {
            return
        }
        Issue.record("\(message), actual: \(vpnConnectionStatus)")
    }

    private func assertDisconnectedStatus(_ message: String = "Expected connection status to be disconnected") {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus
        if case .disconnected = vpnConnectionStatus {
            return
        }
        Issue.record("\(message), actual: \(vpnConnectionStatus)")
    }
}

private class ManagerFactoryMock: AppSessionManagerImplementation.Factory {
    @Dependency(\.date) var date

    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private let alertService: CoreAlertService
    private let updateChecker: UpdateChecker

    let announcementRefresherMock = AnnouncementRefresherMock()
    let appSessionRefreshTimerMock = AppSessionRefreshTimerMock()

    let profileManager = ProfileManager(
        profileStorage: ProfileStorage()
    )

    func makeAnnouncementRefresher() -> AnnouncementRefresher {
        announcementRefresherMock
    }

    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        appSessionRefreshTimerMock
    }

    func makeCoreAlertService() -> CoreAlertService {
        alertService
    }

    func makeProfileManager() -> ProfileManager {
        profileManager
    }

    func makeVpnAuthentication() -> VpnAuthentication {
        VpnAuthenticationMock()
    }

    func makeNetworking() -> Networking {
        NetworkingMock()
    }

    func makeUpdateChecker() -> any UpdateChecker {
        updateChecker
    }

    init(
        alertService: CoreAlertService,
        updateChecker: UpdateChecker
    ) {
        self.alertService = alertService
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

    func fetch(forContext _: AppContext?) -> AuthCredentials? {
        credentials
    }

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
            Issue.record("Unexpected alert was shown: \(alert)")
            return
        }
        alertHandler.handler(alert)
    }
}

private extension SystemAlert {
    func triggerHandler(forFirstActionOfType type: PrimaryActionType) {
        actions.first { $0.style == type }?.handler?()
    }
}
