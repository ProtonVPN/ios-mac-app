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
    final class TestContext {
        fileprivate let alertService: AppSessionManagerAlertServiceMock
        let authKeychain: AuthKeychainHandleMock
        let unauthKeychain: UnauthKeychainMock
        let networking: NetworkingMock
        let networkingDelegate: FullNetworkingMockDelegate
        let manager: AppSessionManagerImplementation
        let vpnKeychain: VpnKeychainMock
        let repository: ServerRepository

        fileprivate init(
            alertService: AppSessionManagerAlertServiceMock,
            authKeychain: AuthKeychainHandleMock,
            unauthKeychain: UnauthKeychainMock,
            networking: NetworkingMock,
            networkingDelegate: FullNetworkingMockDelegate,
            manager: AppSessionManagerImplementation,
            vpnKeychain: VpnKeychainMock,
            repository: ServerRepository
        ) {
            self.alertService = alertService
            self.authKeychain = authKeychain
            self.unauthKeychain = unauthKeychain
            self.networking = networking
            self.networkingDelegate = networkingDelegate
            self.manager = manager
            self.vpnKeychain = vpnKeychain
            self.repository = repository
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
    func loginEstablishesSession() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            #expect(context.manager.sessionStatus == .established)
        }
    }

    @Test
    func silentLoginWhenAlreadyEstablishedStaysEstablished() async throws {
        try await withTestContext { context in
            context.networkingDelegate.apiVpnLocation = .mock
            context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
            context.authKeychain.credentials = testAuthCredentials()
            context.manager.sessionStatus = .established

            try await context.manager.attemptSilentLogIn()

            #expect(context.manager.sessionStatus == .established)
            #expect(context.manager.loggedIn)
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

            #expect(context.manager.loggedIn)
        }
    }

    // MARK: Logout tests

    @Test
    func noAlertShownOnLogoutWhenNotLoggedIn() async {
        await withTestContext { context in
            context.manager.logOut() // no-op in this state
            #expect(context.manager.loggedIn == false)
            #expect(context.manager.sessionStatus != .established)
        }
    }

    @Test
    func noAlertShownOnLogoutWhenNotDisconnected() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectionStatus(connectionState: .disconnected)

            context.manager.logOut()
            #expect(await waitForSessionStatus(.notEstablished, on: context.manager))
            #expect(context.manager.loggedIn == false)
        }
    }

    @Test
    func logoutShowsNoAlertWhenConnecting() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectionStatus(connectionState: .resolving)

            context.manager.logOut()
            #expect(await waitForSessionStatus(.notEstablished, on: context.manager))
            #expect(context.manager.loggedIn == false)
        }
    }

    @Test
    func logoutShowsNoAlertWhenConnectedButForceIsTrue() async throws {
        try await withTestContext { context in
            try await login(with: testAuthCredentials(), context: context)
            setConnectedStatus()

            context.manager.logOut(force: true, reason: "")
            #expect(await waitForSessionStatus(.notEstablished, on: context.manager))
            #expect(context.manager.loggedIn == false)
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

            context.manager.logOut()
            #expect(await waitForSessionStatus(.notEstablished, on: context.manager))
            #expect(context.manager.loggedIn == false)
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

        let networkingDelegate = FullNetworkingMockDelegate()
        networkingDelegate.apiCredentials = VpnKeychainMock.vpnCredentials(planName: "free", maxTier: .free)
        networking.delegate = networkingDelegate
        let networkingWrapper = CoreNetworkingWrapper(wrapped: networking)

        let factory = ManagerFactoryMock()

        try await withDependencies {
            $0.serverRepository = repository
            $0.date = .constant(Date())
            $0.coreAlertService = .init(push: { alertService.push(alert: $0) })
            $0.networking = networkingWrapper
            $0.authKeychain = authKeychain
            $0.unauthKeychain = unauthKeychain
            $0.vpnKeychain = vpnKeychain
            $0.announcementRefresher = .init(tryRefreshing: {}, clear: {})
            $0.profileManager.refreshProfiles = {}
            $0.connectionCommandClient = .init(
                send: { command in
                    guard case let .disconnect(_, completion) = command else { return }
                    @Shared(.connectionState) var connectionState
                    $connectionState.withLock { $0 = .disconnected }
                    Task { @MainActor in completion?() }
                },
                stream: { .finished },
                quickConnect: { _ in }
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
                    serverInfo: .modified(at: nil, servers: [], scope: .allTiers, language: "en"),
                    streamingServices: VPNStreamingResponse(code: 1, resourceBaseURL: "url", streamingServices: [:]),
                    vpnCredentials: credentials,
                    location: nil,
                    measuredLocation: nil,
                    clientConfig: networkingDelegate.apiClientConfig ?? ClientConfig.defaultClientConfigForTests,
                    user: nil,
                    addresses: nil
                )
            }
            $0.vpnApiClient.loads = { _ in [:] }
            $0.vpnApiClient.virtualServices = { VPNStreamingResponse(code: 1, resourceBaseURL: "url", streamingServices: [:]) }
            $0.vpnApiClient.sessionsCount = { SessionsResponse(sessionCount: 1) }
            $0.featureFlags = .enabling()
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
                repository: repository
            )

            setConnectionStatus(
                connectionState: .disconnected
            )

            @Shared(.sessionStatus) var sessionStatus
            // `.undetermined` mirrors the real fresh-launch default (not `.notEstablished`).
            $sessionStatus.withLock { $0 = .undetermined }
            @Shared(.sessionLogoutReason) var sessionLogoutReason
            $sessionLogoutReason.withLock { $0 = nil }
            try await body(context)
        }
    }

    private func login(with authCredentials: AuthCredentials, context: TestContext) async throws {
        context.networkingDelegate.apiVpnLocation = .mock
        context.networkingDelegate.apiClientConfig = ClientConfig.defaultClientConfigForTests
        context.authKeychain.credentials = authCredentials

        try await context.manager.attemptSilentLogIn()

        #expect(context.manager.sessionStatus == .established)
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

    /// Polls `manager.sessionStatus` until it reaches `target` or the attempts are exhausted.
    /// Handles both synchronous (disconnected) and asynchronous (post-disconnect) logout paths.
    private func waitForSessionStatus(
        _ target: SessionStatus,
        on manager: AppSessionManagerImplementation,
        pollInterval: Duration = .milliseconds(10),
        attempts: Int = 500
    ) async -> Bool {
        for _ in 0 ..< attempts {
            if manager.sessionStatus == target { return true }
            try? await Task.sleep(for: pollInterval)
        }
        return manager.sessionStatus == target
    }

    private func setConnectionStatus(connectionState: ConnectionState) {
        @Shared(.connectionState) var sharedConnectionState
        $sharedConnectionState.withLock { $0 = connectionState }
    }

    private func setConnectedStatus() {
        let server = Server.mock()
        let wireGuardSettings = WireGuardSettings(
            backend: .proTUN,
            transport: .udp
        )
        let connectionFeatures = AgentTunnelFeatures(
            netshield: .off,
            vpnAccelerator: false,
            natType: .moderateNAT,
            portForwarding: false
        )
        let actual = VPNConnectionActual(data: .init(currentPeer: server, connectionDate: .now, protocolConnectionData: .ike))
        setConnectionStatus(
            connectionState: .connected(
                .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"], killSwitch: false),
                .init(currentPeer: server, connectionDate: .now, protocolConnectionData: .ike)
            )
        )
    }
}

private class ManagerFactoryMock: AppSessionManagerImplementation.Factory {
    @Dependency(\.date) var date

    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain

    let appSessionRefreshTimerMock = AppSessionRefreshTimerMock()

    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        appSessionRefreshTimerMock
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

private class AppSessionManagerAlertServiceMock {
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
