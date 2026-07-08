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
    @Dependency(\.searchStorageNew) private var searchStorage
    @Dependency(\.networking) private var networking
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.vpnApiClient) private var vpnApiClient

    @Dependency(\.announcementRefresher) var announcementRefresher: AnnouncementRefresher
    @Dependency(\.paymentsPlanServiceV2) private var planServiceV2
    @Dependency(\.propertiesManager) private var propertiesManager
    @Shared(.connectionState) private var connectionState: ConnectionState
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
        do {
            @Dependency(\.userSettingsClient) var userSettingsClient
            let userSettings = try await userSettingsClient.fetchUserSettings(authCredentials: authKeychain.fetch())
            propertiesManager.userSettings = userSettings
            propertiesManager.userInfo?.apply(userSettings)
        } catch {
            log.error("UserSettings error", category: .app, metadata: ["error": "\(error)"])
        }
        try await retrievePropertiesAndLogIn()
    }

    @MainActor
    func finishLogin(authCredentials: AuthCredentials) async throws {
        do {
            try authKeychain.store(authCredentials, source: .userLogin)
            unauthKeychain.clear()
            vpnKeychain.clear()
            propertiesManager.logoutCleanup()
        } catch {
            throw CommonVpnError.keychainWriteFailed
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
        !isServerRepositoryEmpty && propertiesManager.userLocation?.ip != nil
    }

    func loadDataWithoutLogin() async throws {
        @Dependency(\.serverManager) var serverManager
        @Dependency(\.serverRepository) var serverRepository

        log.info("Attempting to load data without login")

        let shouldRefreshServers = !serverManager.shouldFetchFullServerList
        let properties: VpnProperties
        do {
            properties = try await vpnApiClient.vpnProperties(
                isDisconnected: connectionState.isDisconnectedForPropertiesRefresh,
                lastKnownLocation: propertiesManager.userLocation,
                serversAccordingToTier: shouldRefreshServers
            )
        } catch {
            log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])

            // only fail if there is a major reason
            if isServerRepositoryEmpty || propertiesManager.userLocation?.ip == nil {
                throw error
            }

            serverRepository.setMetadata("0", for: .consecutiveSuccessfulRefreshes)
            return
        }

        let credentials = properties.vpnCredentials
        vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = credentials.planName }

        if case let .modified(lastModified, servers, isFreeTier) = properties.serverInfo {
            let isFreeTierRequest = shouldRefreshServers && properties.vpnCredentials.maxTier.isFreeTier
            assert(isFreeTierRequest == isFreeTier)
            serverManager.update(
                servers: servers.map { VPNServer(legacyModel: $0) },
                freeServersOnly: isFreeTierRequest,
                lastModifiedAt: lastModified
            )
        }

        propertiesManager.userLocation = properties.location
        do {
            try await resolveActiveSession()
        } catch {
            logOutCleanup()
            throw error
        }
    }

    // swiftlint:disable function_body_length
    private func retrievePropertiesAndLogIn() async throws {
        @Dependency(\.serverManager) var serverManager
        let shouldRefreshServersAccordingToTier = !serverManager.shouldFetchFullServerList

        async let status = try planServiceV2.fetchIAPStatus()

        // Get VPN properties from API and save them
        do {
            let properties = try await vpnApiClient.vpnProperties(
                isDisconnected: connectionState.isDisconnectedForPropertiesRefresh,
                lastKnownLocation: propertiesManager.userLocation,
                serversAccordingToTier: shouldRefreshServersAccordingToTier
            )

            let credentials = properties.vpnCredentials
            vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)

            // populate (possibly) updated userTier and plan
            @Shared(.userTier) var userTier
            $userTier.withLock { $0 = credentials.maxTier }

            @Shared(.userPlan) var userPlan
            $userPlan.withLock { $0 = credentials.planName }

            if case let .modified(lastModified, servers, isFreeTier) = properties.serverInfo {
                let isFreeTierRequest = shouldRefreshServersAccordingToTier && credentials.maxTier.isFreeTier
                assert(isFreeTierRequest == isFreeTier)
                serverManager.update(
                    servers: servers.map { VPNServer(legacyModel: $0) },
                    freeServersOnly: isFreeTierRequest,
                    lastModifiedAt: lastModified
                )
            }

            propertiesManager.userRole = properties.userRole

            @Shared(.userAccountCreationDate) var userAccountCreationDate
            $userAccountCreationDate.withLock { $0 = properties.userCreateTime }

            propertiesManager.userLocation = properties.location
            propertiesManager.userAccountRecovery = properties.userAccountRecovery
            propertiesManager.userInfo = properties.userInfo
            if let userSettings = propertiesManager.userSettings {
                propertiesManager.userInfo?.apply(userSettings)
            }
            if let clientConfig = properties.clientConfig {
                @Shared(.smartProtocolConfig) var smartProtocolConfig
                $smartProtocolConfig.withLock { $0 = clientConfig.smartProtocolConfig }
                propertiesManager.maintenanceServerRefreshIntereval = clientConfig.serverRefreshInterval
                @Shared(.featureFlags) var featureFlags
                $featureFlags.withLock { $0 = clientConfig.featureFlags }

                @Shared(.ratingSettings) var ratingSettings
                $ratingSettings.withLock { $0 = clientConfig.ratingSettings }

                @Dependency(\.serverChangeStorage) var storage
                storage.config = clientConfig.serverChangeConfig
            }
            if let streamingServices = properties.streamingResponse {
                propertiesManager.streamingServices = streamingServices.streamingServices
                propertiesManager.streamingResourcesUrl = streamingServices.resourceBaseURL
            }
            @Shared(.featureFlags) var pollFeatureFlags
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
            if isServerRepositoryEmpty || propertiesManager.userLocation?.ip == nil {
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
                propertiesManager.userAccountRecovery = user.accountRecovery
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
            alertService.push(alert: LogoutWarningAlert(confirmHandler: confirmationClosure))
        }
    }

    private func logOutCleanup() {
        refreshTimer.stopTimers()
        loggedIn = false

        if let userId = authKeychain.userId {
            FeatureFlagsRepository.shared.resetFlags(for: userId)
        }

        FeatureFlagsRepository.shared.clearUserId()

        authKeychain.clear(.logOutCleanup)
        vpnKeychain.clear()
        announcementRefresher.clear()

        searchStorage.clear()
        planServiceV2.clear()

        @Shared(.userPlan) var userPlan
        $userPlan.withLock { $0 = nil }

        @Dependency(\.serverManager) var serverManager
        serverManager.purgeAllServers()

        propertiesManager.logoutCleanup()

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
            propertiesManager.hasConnected = true
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
