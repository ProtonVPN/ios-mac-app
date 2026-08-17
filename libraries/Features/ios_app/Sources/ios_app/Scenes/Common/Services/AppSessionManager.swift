//
//  AppSessionManager.swift
//  ProtonVPN - Created on 01.07.19.
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
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN. If not, see <https://www.gnu.org/licenses/>.
//

import Announcement
import CommonNetworking
import Connection
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Payments
import ProtonCoreFeatureFlags
import Sharing
import Strings
import Telemetry
import UIKit
import VPNAppCore
import VPNShared

/// Advanced kill switch is Active when the mode is Advanced and the reported tunnel actually carries
/// the kill switch flag, meaning it is connected with it or already blocking. A mode that was enabled
/// mid-session only applies to the next connection and does not count as Active.
private func isAdvancedKillSwitchActive() -> Bool {
    @SharedReader(.connectionState) var connectionState
    @SharedReader(.killSwitchMode) var killSwitchMode
    return killSwitchMode.isAdvanced && connectionState.tunnelKillSwitch
}

protocol AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager
}

protocol AppSessionManager {
    func attemptSilentLogIn() async throws
    func finishLogin(authCredentials: AuthCredentials) async throws
    func logOut(force: Bool, reason: String?)

    func loadDataWithoutFetching() -> Bool
    func loadDataWithoutLogin() async throws
    func canPreviewApp() -> Bool
    func refreshUserInfo()
}

final class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {
    typealias Factory = AppSessionRefreshTimerFactory & NavigationServiceFactory
    private let factory: Factory

    private var navService: NavigationService? {
        factory.makeNavigationService()
    }

    private lazy var refreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    @Dependency(\.networking) private var networking
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.vpnApiClient) private var vpnApiClient

    @Dependency(\.announcementRefresher) var announcementRefresher: AnnouncementRefresher
    @Dependency(\.paymentsPlanServiceV2) private var planServiceV2
    @SharedReader(.connectionState) private var connectionState: ConnectionState
    /// session status, single source of truth
    @Shared(.sessionStatus) private var sharedSessionStatus: SessionStatus
    /// Reason for a forced logout to login/welcome screens
    @Shared(.sessionLogoutReason) private var sessionLogoutReason: String?

    var sessionStatus: SessionStatus {
        get { sharedSessionStatus }
        set {
            $sharedSessionStatus.withLock { $0 = newValue }
            log.info("Session status is now \(newValue)", category: .app)
        }
    }

    private var refreshUserInfoTask: Task<Void, Error>?
    private var paymentTransactionEvents: Task<Void, Never>?

    // MARK: - Init

    init(factory: Factory) {
        self.factory = factory
        super.init()

        AppEvent.userEngagedWithUpsellAlert.subscribe(self, selector: #selector(userEngagedWithUpsell))
    }

    /// On iOS an unsupported app version can't self-update, so the alert forces a logout
    override func presentAppUpdateRequired(_ error: Error) {
        let alert = AppUpdateRequiredAlert(error)
        alert.actions.append(AlertAction(title: Localizable.ok, style: .confirmative) { [weak self] in
            self?.logOut(force: true, reason: nil)
        })
        alertService.push(alert: alert)
    }

    // MARK: - Beginning of the login logic.

    @MainActor
    override func attemptSilentLogIn() async throws {
        guard authKeychain.fetch()?.username != nil else {
            throw CommonVpnError.userCredentialsMissing
        }

        try await retrievePropertiesAndLogIn()
    }

    @MainActor
    func finishLogin(authCredentials: AuthCredentials) async throws {
        do {
            try authKeychain.store(authCredentials, source: .userLogin)
            unauthKeychain.clear()
            vpnKeychain.clear()
            performLogoutCleanup()
        } catch {
            throw CommonVpnError.keychainWriteFailed
        }

        do {
            @Dependency(\.userSettingsClient) var userSettingsClient
            @Shared(.userSettings) var userSettings
            @Shared(.userInfo) var userInfo
            let fetchedSettings = try await userSettingsClient.fetchUserSettings(authCredentials: authCredentials)
            $userSettings.withLock { $0 = fetchedSettings }
            $userInfo.withLock { $0?.apply(fetchedSettings) }
        } catch {
            log.error("Failed to obtain user settings", category: .user, metadata: ["error": "\(error)"])
        }

        do {
            try await retrievePropertiesAndLogIn()
            checkIfOSIsSupportedInNextUpdateAndAlertIfNeeded()
        } catch {
            log.error("Failed to obtain user's auth credentials", category: .user, metadata: ["error": "\(error)"])
            throw error
        }
    }

    private var isServerRepositoryEmpty: Bool {
        @Dependency(\.serverRepository) var serverRepository
        return serverRepository.isEmpty
    }

    func loadDataWithoutFetching() -> Bool {
        if isServerRepositoryEmpty {
            return false
        }

        do {
            _ = try vpnKeychain.fetchCached()
            let _: AuthCredentials = try authKeychain.fetch()
            setAndNotify(for: .established, reason: nil)
        } catch {
            log.info("User is not logged in", metadata: ["reason": "\(error)"])
            setAndNotify(for: .notEstablished, reason: nil)
        }
        return true
    }

    func canPreviewApp() -> Bool {
        @SharedReader(.userLocation) var userLocation
        return !isServerRepositoryEmpty && userLocation?.location.ip != nil
    }

    func loadDataWithoutLogin() async throws {
        @Dependency(\.serverListUpdater) var serverListUpdater
        @Dependency(\.serverRepository) var serverRepository

        log.info("Attempting to load data without login")

        @SharedReader(.userLocation) var userLocation
        // The endpoint is only asked for a location while no tunnel is up; otherwise it answers with
        // the exit address, and the properties come back carrying whatever we passed in.
        let measuresLocation = connectionState.isDisconnectedForPropertiesRefresh
        let shouldRefreshServers = !serverRepository.shouldFetchFullServerList
        let properties: VpnProperties
        do {
            properties = try await vpnApiClient.vpnProperties(
                isDisconnected: measuresLocation,
                lastKnownLocation: userLocation?.location,
                serversAccordingToTier: shouldRefreshServers
            )
        } catch {
            log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])

            // only fail if there is a major reason
            if isServerRepositoryEmpty || userLocation?.location.ip == nil {
                throw error
            }

            serverRepository.resetSuccessfulRefreshes()
            return
        }

        let credentials = properties.vpnCredentials
        vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)

        if case let .modified(lastModified, servers, isFree) = properties.serverInfo {
            let isFreeTierRequest = shouldRefreshServers && properties.vpnCredentials.maxTier.isFree
            assert(isFreeTierRequest == isFree)
            serverListUpdater.update(
                servers: servers,
                freeServersOnly: isFreeTierRequest,
                lastModifiedAt: lastModified
            )
        }

        // Manager calls `recordMeasured` only when `measuredLocation` exists. It checks the state a second
        // time because the tunnel can connect while the request is in flight (request will fail)
        if let measured = properties.measuredLocation, connectionState.isDisconnectedForPropertiesRefresh {
            @Shared(.userLocation) var userLocation
            $userLocation.recordMeasured(measured)
        }
        do {
            try await resolveActiveSession()
        } catch {
            logOutCleanup()
            throw error
        }
    }

    // swiftlint:disable function_body_length
    private func retrievePropertiesAndLogIn() async throws {
        @Dependency(\.serverListUpdater) var serverListUpdater
        @Dependency(\.serverRepository) var serverRepository
        let shouldRefreshServersAccordingToTier = !serverRepository.shouldFetchFullServerList

        @SharedReader(.userLocation) var userLocation
        let measuresLocation = connectionState.isDisconnectedForPropertiesRefresh

        async let status = try planServiceV2.fetchIAPStatus()

        // Get VPN properties from API and save them
        do {
            let properties = try await vpnApiClient.vpnProperties(
                isDisconnected: measuresLocation,
                lastKnownLocation: userLocation?.location,
                serversAccordingToTier: shouldRefreshServersAccordingToTier
            )

            let credentials = properties.vpnCredentials
            vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)

            if case let .modified(lastModified, servers, isFree) = properties.serverInfo {
                let isFreeTierRequest = shouldRefreshServersAccordingToTier && credentials.maxTier.isFree
                assert(isFreeTierRequest == isFree)
                serverListUpdater.update(
                    servers: servers,
                    freeServersOnly: isFreeTierRequest,
                    lastModifiedAt: lastModified
                )
            }

            @Shared(.userAccountCreationDate) var userAccountCreationDate
            $userAccountCreationDate.withLock { $0 = properties.userCreateTime }

            if let measured = properties.measuredLocation, connectionState.isDisconnectedForPropertiesRefresh {
                @Shared(.userLocation) var userLocation
                $userLocation.recordMeasured(measured)
            }
            @Shared(.userAccountRecovery) var userAccountRecovery
            $userAccountRecovery.withLock { $0 = properties.userAccountRecovery }
            @Shared(.userInfo) var userInfo
            $userInfo.withLock { $0 = properties.userInfo }
            @SharedReader(.userSettings) var userSettings
            if let userSettings {
                $userInfo.withLock { $0?.apply(userSettings) }
            }
            if let clientConfig = properties.clientConfig {
                @Shared(.smartProtocolConfig) var smartProtocolConfig
                $smartProtocolConfig.withLock { $0 = clientConfig.smartProtocolConfig }
                @Shared(.maintenanceServerRefreshIntereval) var maintenanceServerRefreshIntereval
                $maintenanceServerRefreshIntereval.withLock { $0 = clientConfig.serverRefreshInterval }
                @Shared(.featureFlags) var featureFlags
                $featureFlags.withLock { $0 = clientConfig.featureFlags }

                @Shared(.ratingSettings) var ratingSettings
                $ratingSettings.withLock { $0 = clientConfig.ratingSettings }

                @Shared(.serverChangeConfig) var serverChangeConfig
                $serverChangeConfig.withLock { $0 = clientConfig.serverChangeConfig }
            }
            if let streamingResponse = properties.streamingResponse {
                @Shared(.streamingServices) var streamingServices
                @Shared(.streamingResourcesUrl) var streamingResourcesUrl
                $streamingServices.withLock { $0 = streamingResponse.streamingServices }
                $streamingResourcesUrl.withLock { $0 = streamingResponse.resourceBaseURL }
            }
            @SharedReader(.featureFlags) var pollFeatureFlags
            if pollFeatureFlags.pollNotificationAPI {
                announcementRefresher.tryRefreshing()
            }

            _ = try? await status
            startListeningToPaymentTransactionEvents()
        } catch CommonVpnError.subuserWithoutSessions {
            log.error("User with insufficient sessions detected. Throwing an error instead of logging in.", category: .app)
            logOutCleanup()
            throw CommonVpnError.subuserWithoutSessions
        } catch CommonVpnError.noConnectionsAvailable {
            log.error("User with no connections assigned. Throwing an error instead of logging in.", category: .app)
            logOutCleanup()
            throw CommonVpnError.noConnectionsAvailable
        } catch {
            // In case getting vpn properties fails, we don't log user out in all cases. Instead
            // check if we can continue.
            // If user has the list of servers and IP is already saved, we can continue
            // and update vpnProperties later.
            // Also the error has to be not keychain related, because if there is a problem with
            // the keychain, use most probably will not be able to use API nor VPN connection.
            log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])
            if isServerRepositoryEmpty || userLocation?.location.ip == nil {
                throw error
            }
        }

        // In case we are connected to VPN, but can't get auth info from connection-aware state nor
        // from `vpnKeychain`, we fail miserably and log out.
        do {
            try await resolveActiveSession()
        } catch {
            logOutCleanup()
            throw error
        }
        await MainActor.run {
            setAndNotify(for: .established, reason: nil)
        }
        @Dependency(\.profileManager) var profileManager
        profileManager.refreshProfiles()
    }

    // swiftlint:enable function_body_length

    private func resolveActiveSession() async throws {
        guard connectionState.isConnectedForSessionValidation else {
            return // Success
        }

        guard (try? vpnKeychain.fetch()) != nil else {
            throw CommonVpnError.fetchSession // Error
        }
    }

    func refreshUserInfo() {
        guard FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.accountRecovery, reloadValue: true),
              refreshUserInfoTask == nil else { return }
        refreshUserInfoTask = Task { [weak self] in
            guard let self else { return }
            do {
                let user = try await vpnApiClient.userInfo()
                @Shared(.userAccountRecovery) var userAccountRecovery
                $userAccountRecovery.withLock { $0 = user.accountRecovery }
                await MainActor.run {
                    AppEvent.sessionManagerDataReloaded.post()
                }
            } catch {
                log.error("Could not refresh User info", category: .api)
            }
            refreshUserInfoTask = nil
        }
    }

    // MARK: - Log out

    func logOut(force: Bool = false, reason: String?) {
        let logOutRoutine: () -> Void = { [weak self] in
            self?.loggedIn = false
            self?.logOutCleanup()
            self?.setAndNotify(for: .notEstablished, reason: reason)
        }

        // Defensive measure regarding VPNAPPL-2902
        if !loggedIn, case .notEstablished = sessionStatus, reason == Localizable.invalidRefreshTokenPleaseLogin {
            log.info("Preventing logOut procedure since user is not logged in")
            return
        }

        @Dependency(\.settingsClient) var settingsClient

        if !settingsClient.isActive() {
            logOutRoutine()
            return
        }

        let confirmationClosure: () -> Void = {
            // Only keep blocking if Advanced Kill Switch was actually applied to the connection, not merely requested
            // for the next one.
            if isAdvancedKillSwitchActive() {
                // Advanced KS persists across sign-out. Switch the current tunnel to zero-peer mode so it keeps
                // blocking on the login screen, without tearing it down. The switch works using the `vpnTunnelControl`
                // dependency rather than the connection feature, because signout tears down its TCA store.
                @Dependency(\.vpnTunnelControl) var vpnTunnelControl
                @SharedReader(.connectionState) var connectionState
                Task { [weak self] in
                    // Sign out first: session teardown fires network calls (server-side session
                    // invalidation, unauthenticated session acquisition) that the blackhole would cut
                    // off. Running it before the switch below only gives those calls a head start,
                    // not a guarantee, since logOutRoutine dispatches them asynchronously. The tunnel
                    // keeps protecting traffic the whole time.
                    logOutRoutine()

                    // Only convert a live tunnel; if already blocking there's nothing to switch.
                    guard connectionState.is(\.connected) else { return }
                    do {
                        try await vpnTunnelControl.enterZeroPeerBlocking()
                    } catch {
                        // Advanced KS is meant to keep blocking after sign-out; a failure here means the
                        // device may no longer be protected, so log it and warn the user.
                        log.error("Failed to enter zero-peer kill switch blocking on sign-out: \(error)", category: .connection)
                        self?.alertService.push(alert: KillSwitchLogoutBlockingFailedAlert())
                    }
                }
                return
            }

            if settingsClient.isActive() {
                Task {
                    do {
                        try await settingsClient.disconnect()
                        logOutRoutine()
                    } catch {
                        log.error("Failed to disconnect: \(error)", category: .connection)
                    }
                }
                return
            }

            logOutRoutine()
        }

        if force {
            confirmationClosure()
        } else {
            if isAdvancedKillSwitchActive() {
                // Signing out with active Advanced KS keeps the device offline; a mode that is merely
                // requested for the next connection uses the normal warning.
                alertService.push(alert: LogoutWithAdvancedKillSwitchAlert(username: authKeychain.username, confirmHandler: confirmationClosure))
            } else {
                alertService.push(alert: LogoutWarningAlert(confirmHandler: confirmationClosure))
            }
        }
    }

    private func logOutCleanup() {
        refreshTimer.stopTimers()
        loggedIn = false

        // Standard kill switch auto-disables on logout so the user isn't locked out of the
        // internet. Advanced persists until explicitly disabled.
        @Shared(.killSwitchMode) var killSwitchMode
        $killSwitchMode.withLock { if $0 == .standard { $0 = .off } }

        if let userId = authKeychain.userId {
            FeatureFlagsRepository.shared.resetFlags(for: userId)
        }

        FeatureFlagsRepository.shared.clearUserId()

        authKeychain.clear(.logOutCleanup)
        vpnKeychain.clear()
        announcementRefresher.clear()

        @Shared(.recentSearches) var storedSearches
        $storedSearches.withLock { $0 = nil }
        planServiceV2.clear()

        @Dependency(\.serverRepository) var serverRepository
        serverRepository.deleteAllServers()

        performLogoutCleanup()

        networking.apiService.acquireSessionIfNeeded { _ in }
        paymentTransactionEvents?.cancel()
        paymentTransactionEvents = nil
    }

    // End of the logout logic

    // MARK: -

    // Updates the status of the app
    private func setAndNotify(for state: SessionStatus, reason: String?) {
        guard !loggedIn else { return }

        // clear/set the logout reason before updating sessionStatus
        if state == .established {
            $sessionLogoutReason.withLock { $0 = nil }
        } else if state == .notEstablished {
            $sessionLogoutReason.withLock { $0 = reason }
        }

        sessionStatus = state
        if state == .established {
            loggedIn = true
            @Shared(.hasConnected) var hasConnected
            $hasConnected.withLock { $0 = true }
        } else if state == .notEstablished {
            // Clear auth token and vpn creds to ensure they won't be used
            logOutCleanup()
        }

        refreshTimer.startTimers()
    }

    // MARK: Start listening to payment transaction events from both services

    private func startListeningToPaymentTransactionEvents() {
        paymentTransactionEvents?.cancel()
        paymentTransactionEvents = Task.detached { [weak self] in
            guard let self else { return }
            for await event in NotificationCenter.default.notifications(named: AppEvent.userDidCompletePurchase.name) {
                guard let object = event.object as? PaymentTransactionFinishedEvent else {
                    continue
                }

                await handlePaymentTransactionFinished(event: object)
            }
        }
    }

    // MARK: Attempt to pass telemetry on web purchases

    private var userEngagedWithWebUpsellDate: Date?
    private static let webPaymentsThreshold: TimeInterval = .minutes(15)

    @objc
    private func userEngagedWithUpsell(_ notification: Notification) {
        @Dependency(\.date.now) var now
        // check if we have stale info
        if let userEngagedWithWebUpsellDate {
            if now.timeIntervalSince(userEngagedWithWebUpsellDate) > Self.webPaymentsThreshold {
                self.userEngagedWithWebUpsellDate = nil
            }
        }
        guard let upsellData = notification.object as? UpsellData else { return }
        // ensure that this was web purchase attempt
        guard upsellData.flowType == .external else { return }
        userEngagedWithWebUpsellDate = now
    }

    // MARK: User plan changed (before refreshing data)

    override func userPlanChanged(_ notification: Notification) {
        @Dependency(\.date.now) var now
        if let downgradeInfo = notification.object as? VpnDowngradeInfo,
           downgradeInfo.from.maxTier < downgradeInfo.to.maxTier,
           // we have web upsell engagement info
           let userEngagedWithWebUpsellDate,
           // it happened within a threshold
           now.timeIntervalSince(userEngagedWithWebUpsellDate) < Self.webPaymentsThreshold {
            // At some point it may be possible to plumb the modal source through from the redirect deep link.
            // For now we will leave it nil and let the telemetry service take its best guess.
            let modalSource: UpsellModalSource? = nil
            let upsellSuccessData = UpsellData.webIntro(
                modalSource: modalSource,
                newPlanName: downgradeInfo.to.planName
            )
            AppEvent.userCompletedUpsellAlertJourney.post(upsellSuccessData)
            self.userEngagedWithWebUpsellDate = nil
        }

        super.userPlanChanged(notification) // refreshes data
    }
}

// MARK: - Plan change

extension AppSessionManagerImplementation {
    @MainActor
    private func handlePaymentTransactionFinished(event: PaymentTransactionFinishedEvent) async {
        guard authKeychain.username != nil else {
            return
        }

        let upsellSuccessData = UpsellData(
            modalSource: nil,
            newPlanName: event.newPlanName,
            reference: event.offerReference,
            cycle: event.cycle,
            flowType: event.flowType.flatMap { UpsellEvent.FlowType(rawValue: $0.rawValue) }
        )
        // Note: Do not async this part, we don't want it to race with retrieving the new properties below.
        AppEvent.userCompletedUpsellAlertJourney.post(upsellSuccessData)
        log.debug("Reloading data after plan purchase", category: .app)
        do {
            try await retrievePropertiesAndLogIn()
            AppEvent.sessionManagerDataReloaded.post()
        } catch {
            log.error("Data reload failed after plan purchase", category: .app, metadata: ["error": "\(error)"])
        }
    }
}
