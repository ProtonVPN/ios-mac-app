//
//  AppSessionManager.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Announcement
import Cocoa
import CommonNetworking
import Connection
import Dependencies
import Domain
import Ergonomics
import ExtensionManager
import LegacyCommon
import os
import ProtonCoreFeatureFlags
import ProtonCoreUtilities
import Sharing
import Strings
import Telemetry
import VPNAppCore // UnauthKeychain
import VPNShared

protocol AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager
}

protocol AppSessionManager {
    func attemptSilentLogIn() async throws
    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logOut(force: Bool, reason: String?)
    func logOut()

    func replyToApplicationShouldTerminate()
}

final class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {
    typealias Factory = AppSessionRefreshTimerFactory
    private let factory: Factory

    private lazy var appSessionRefreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    @Dependency(\.profileManager) private var profileManager
    @Dependency(\.systemExtensionsCoordinator) private var systemExtensionsCoordinator
    @Dependency(\.networking) private var networking
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.vpnApiClient) private var vpnApiClient
    @Dependency(\.announcementRefresher) var announcementRefresher: AnnouncementRefresher
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.activeTunnelInspector) private var activeTunnelInspector
    @Dependency(\.updateManager) private var updateManager
    @Shared(.connectionState) private var connectionState: ConnectionState
    /// session status, single source of truth
    @Shared(.sessionStatus) private var sharedSessionStatus: SessionStatus
    /// Reason for a forced logout to login/welcome screens
    @Shared(.sessionLogoutReason) private var sessionLogoutReason: String?

    /// While clearing, the keychains are wiped and the server database is closed and deleted.
    /// However, we must not call logOut multiple times in parallel because we might get race in it, and assertionFailure in the GRDB
    private var isClearingApplicationData = false

    var sessionStatus: SessionStatus {
        get { sharedSessionStatus }
        set {
            $sharedSessionStatus.withLock { $0 = newValue }
            loggedIn = newValue == .established
            log.info("Session status is now \(newValue)", category: .app)
        }
    }

    init(factory: Factory) {
        self.factory = factory
        super.init()
        propertiesManager.restoreStartOnBootStatus()
        AppEvent.clearingApplicationData.subscribe(self, selector: #selector(tearDown(_:)))
    }

    @objc
    private func tearDown(_: Notification) {
        isClearingApplicationData = true
    }

    // MARK: public log in interface (completion handlers)

    @MainActor
    override func attemptSilentLogIn() async throws {
        log.debug("Attempt silent login", category: .app)
        guard authKeychain.fetch() != nil else {
            throw CommonVpnError.userCredentialsMissing
        }
        try await finishLogin()
    }

    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        // Invoke async implementation
        executeOnUIThread({ try await self.attemptLogin(with: authCredentials) }, success: success, failure: failure)
    }

    // MARK: private log in implementation (async)

    private func attemptLogin(with authCredentials: AuthCredentials) async throws {
        do {
            try authKeychain.store(authCredentials, source: .userLogin)
            unauthKeychain.clear()
        } catch {
            throw CommonVpnError.keychainWriteFailed
        }

        try await finishLogin()
    }

    @MainActor
    private func finishLogin() async throws {
        try await retrieveProperties()
        checkIfOSIsSupportedInNextUpdateAndAlertIfNeeded()

        if sessionStatus != .established {
            // Clear any stale logout reason before establishing the session
            $sessionLogoutReason.withLock { $0 = nil }
            sessionStatus = .established
            propertiesManager.hasConnected = true
        }

        appSessionRefreshTimer.startTimers()
        profileManager.refreshProfiles()
    }

    private func retrieveProperties() async throws {
        @Dependency(\.serverRepository) var serverRepository
        guard let properties = try await getVPNProperties() else {
            serverRepository.setMetadata("0", for: .consecutiveSuccessfulRefreshes)
            return
        }

        let shouldRefreshServersAccordingToUserTier = !serverManager.shouldFetchFullServerList
        let credentials = properties.vpnCredentials
        vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
        if case let .modified(lastModified, servers, isFreeTier) = properties.serverInfo {
            let isFreeTierRequest = shouldRefreshServersAccordingToUserTier && credentials.maxTier == .freeTier
            assert(isFreeTierRequest == isFreeTier)
            serverManager.update(
                servers: servers.map { VPNServer(legacyModel: $0) },
                freeServersOnly: isFreeTierRequest,
                lastModifiedAt: lastModified
            )
        }

        if isDisconnectedForPropertiesRefresh {
            propertiesManager.userLocation = properties.location
        }
        propertiesManager.userRole = properties.userRole

        @Shared(.userAccountCreationDate) var userAccountCreationDate
        $userAccountCreationDate.withLock { $0 = properties.userCreateTime }
        @Shared(.userTier) var userTier
        $userTier.withLock { $0 = credentials.maxTier }

        if let clientConfig = properties.clientConfig {
            @Shared(.smartProtocolConfig) var smartProtocolConfig
            $smartProtocolConfig.withLock { $0 = clientConfig.smartProtocolConfig }
            @Shared(.featureFlags) var featureFlags
            $featureFlags.withLock { $0 = clientConfig.featureFlags }
            propertiesManager.maintenanceServerRefreshIntereval = clientConfig.serverRefreshInterval
            @Dependency(\.serverChangeStorage) var storage
            storage.config = clientConfig.serverChangeConfig
        }
        if let streamingServices = properties.streamingResponse {
            propertiesManager.streamingServices = streamingServices.streamingServices
            propertiesManager.streamingResourcesUrl = streamingServices.resourceBaseURL
        }
        @Shared(.featureFlags) var pollFeatureFlags
        if pollFeatureFlags.pollNotificationAPI {
            Task { @MainActor in
                self.announcementRefresher.tryRefreshing()
            }
        }

        do {
            try await resolveActiveSession()
        } catch {
            logOutCleanup()
            throw error
        }
    }

    /// Ignore errors unless one of the following is true:
    /// - API returns `CommonVpnError.subuserWithoutSessions`
    /// - Server storage is empty or user IP is not known
    /// - We hit a keychain error
    private func getVPNProperties() async throws -> VpnProperties? {
        let isDisconnected = isDisconnectedForPropertiesRefresh
        let location = propertiesManager.userLocation

        let shouldRefreshServersAccordingToUserTier = !serverManager.shouldFetchFullServerList
        do {
            return try await vpnApiClient.vpnProperties(
                isDisconnected: isDisconnected,
                lastKnownLocation: location,
                serversAccordingToTier: shouldRefreshServersAccordingToUserTier
            )
        } catch CommonVpnError.subuserWithoutSessions {
            log.error("User with insufficient sessions detected. Throwing an error instead of logging in.", category: .app)
            logOutCleanup()
            throw CommonVpnError.subuserWithoutSessions
        } catch CommonVpnError.noConnectionsAvailable {
            log.error("User with no connections assigned. Throwing an error instead of logging in.", category: .app)
            logOutCleanup()
            throw CommonVpnError.noConnectionsAvailable
        } catch {
            log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])
            @Dependency(\.serverRepository) var serverRepository
            if serverRepository.isEmpty || propertiesManager.userLocation?.ip == nil {
                // only throw if there is a major reason
                throw error
            }
        }
        return nil
    }

    private func resolveActiveSession() async throws {
        guard isConnected else {
            return
        }

        guard let vpnCredentials = try? vpnKeychain.fetch() else {
            logOut(force: true, reason: Localizable.errorSignInAgain)
            throw CommonVpnError.fetchSession
        }

        // IKEv2 is the only protocol that embeds a user identity in its tunnel configuration
        // (`NEVPNProtocolIKEv2.username`). WireGuard tunnels carry no user identity, so the
        // cross-user check is best-effort and only catches the IKE case.
        // TODO: Have wireguard check with ProTUN VPNAPPL-3544
        guard
            let activeBaseUsername = await activeTunnelInspector.activeIKEBaseUsername(),
            activeBaseUsername != vpnCredentials.name
        else {
            return
        }
        try await confirmAndDisconnectActiveSession()
    }

    private static let activeSessionAlertTimeoutSeconds: TimeInterval = 60
    private func confirmAndDisconnectActiveSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // `CheckedContinuation` requires a single resume. The alert has three exit
            // paths (Continue, Cancel, and out-of-band dismissal via Cmd+W / window close
            // / programmatic dismiss) — the last of which fires neither action handler and
            // would otherwise leave this continuation unresumed, hanging the caller forever.
            // Guard against that with a one-shot resume + produce an error if it hangs more than 60s
            let didResume = OSAllocatedUnfairLock<Bool>(initialState: false)
            let resumeOnce: @Sendable (Result<Void, Error>) -> Void = { result in
                let shouldResume = didResume.withLock { resumed in
                    guard !resumed else { return false }
                    resumed = true
                    return true
                }
                guard shouldResume else { return }
                continuation.resume(with: result)
            }

            let alert = ActiveSessionWarningAlert(
                confirmHandler: { [weak self] in
                    guard let self, isConnected else {
                        resumeOnce(.success(()))
                        return
                    }
                    connectionCommandClient.send(.disconnect(.signout, completion: {
                        resumeOnce(.success(()))
                    }))
                },
                cancelHandler: {
                    resumeOnce(.failure(CommonVpnError.vpnSessionInProgress))
                }
            )
            alertService.push(alert: alert)

            Task {
                try? await Task.sleep(for: .seconds(Self.activeSessionAlertTimeoutSeconds))
                resumeOnce(.failure(CommonVpnError.vpnSessionInProgress))
            }
        }
    }

    // MARK: - Log out

    func logOut() {
        logOut(force: false, reason: nil)
    }

    func logOut(force: Bool, reason: String?) {
        guard !isClearingApplicationData else { return }
        guard sessionStatus == .established else { return } // not logged in, nothing to do
        switch connectionState {
        case .connected:
            confirmLogout(showAlert: !force) { [weak self] in
                self?.connectionCommandClient.send(.disconnect(.signout, completion: { [weak self] in
                    self?.logoutRoutine(reason: reason)
                }))
            }
        case .connecting, .disconnecting, .resolving:
            connectionCommandClient.send(.disconnect(.signout, completion: { [weak self] in
                self?.logoutRoutine(reason: reason)
            }))
        case .disconnected:
            logoutRoutine(reason: reason)
        }
    }

    private func confirmLogout(showAlert: Bool, completion: @escaping () -> Void) {
        guard showAlert else {
            completion()
            return
        }

        let logoutAlert = LogoutWarningLongAlert(confirmHandler: { completion() })
        alertService.push(alert: logoutAlert)
    }

    private func logoutRoutine(reason: String?) {
        guard sessionStatus == .established else {
            return // not logged in, nothing to do
        }
        // set the logout reason before updating sessionStatus
        $sessionLogoutReason.withLock { $0 = reason }
        sessionStatus = .notEstablished
        logOutCleanup()
    }

    private func logOutCleanup() {
        appSessionRefreshTimer.stopTimers()

        if let userId = authKeychain.userId {
            FeatureFlagsRepository.shared.resetFlags(for: userId)
            FeatureFlagsRepository.shared.clearUserId()
        }

        authKeychain.clear(.logOutCleanup)
        vpnKeychain.clear()
        announcementRefresher.clear()

        @Dependency(\.serverManager) var serverManager
        serverManager.purgeAllServers()

        propertiesManager.logoutCleanup()

        networking.apiService.acquireSessionIfNeeded { _ in }
    }

    // End of the logout logic

    // MARK: - AppDelegate quit behaviour

    func replyToApplicationShouldTerminate() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if propertiesManager.uninstallSysexesOnTerminate {
                await systemExtensionsCoordinator.uninstallAll(origin: .termination, userInitiated: false)
            }

            // Skip the quit confirmation prompt when Sparkle is relaunching the app to apply an update.
            guard sessionStatus == .established, !isSafeToEnd, !updateManager.isRelaunchingForUpdate() else {
                NSApp.reply(toApplicationShouldTerminate: true)
                return
            }

            let confirmationClosure: () -> Void = { [weak self] in
                self?.connectionCommandClient.send(.disconnect(.exit, completion: {
                    DispatchQueue.main.async {
                        NSApp.reply(toApplicationShouldTerminate: true)
                    }
                }))
            }

            // ensure application data hasn't been cleared
            @Dependency(\.defaultsProvider) var provider
            guard provider.getDefaults().bool(forKey: AppConstants.UserDefaults.launchedBefore) else {
                confirmationClosure()
                return
            }

            let cancellationClosure: () -> Void = { NSApp.reply(toApplicationShouldTerminate: false) }

            let alert = QuitWarningAlert(confirmHandler: confirmationClosure, cancelHandler: cancellationClosure)
            alertService.push(alert: alert)
        }
    }

    // MARK: User plan changed (before refreshing data)

    override func userPlanChanged(_ notification: Notification) {
        if let downgradeInfo = notification.object as? VpnDowngradeInfo,
           downgradeInfo.from.maxTier < downgradeInfo.to.maxTier {
            // At some point it may be possible to plumb the modal source through from the redirect deep link.
            // For now we will leave it nil and let the telemetry service take its best guess.
            let modalSource: UpsellModalSource? = nil
            let upsellSuccessData = UpsellData(
                modalSource: modalSource,
                newPlanName: downgradeInfo.to.planName,
                reference: nil,
                cycle: nil,
                flowType: nil
            )
            AppEvent.userCompletedUpsellAlertJourney.post(upsellSuccessData)
        }

        super.userPlanChanged(notification) // refreshes data
    }

    private var isConnected: Bool {
        connectionState.isConnected
    }

    private var isDisconnectedForPropertiesRefresh: Bool {
        connectionState.isDisconnectedForPropertiesRefresh
    }

    private var isSafeToEnd: Bool {
        connectionState.isSafeToEnd
    }
}
