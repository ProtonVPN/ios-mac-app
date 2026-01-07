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

import Foundation
import UIKit

import Dependencies
import Sharing

import ProtonCoreFeatureFlags

import Announcement
import CommonNetworking
import ExtensionIPC
import LegacyCommon
import Telemetry
import VPNAppCore
import VPNShared

import Domain
import Ergonomics
import Review
import Search
import Strings

enum SessionStatus {
    case notEstablished
    case established
    case undetermined
}

protocol AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager
}

protocol AppSessionManager {
    var vpnGateway: VpnGatewayProtocol { get }
    var sessionStatus: SessionStatus { get set }
    var loggedIn: Bool { get }

    func attemptSilentLogIn() async throws
    func refreshVpnAuthCertificate() async throws
    func finishLogin(authCredentials: AuthCredentials) async throws
    func logOut(force: Bool, reason: String?)

    func loadDataWithoutFetching() -> Bool
    func loadDataWithoutLogin() async throws
    func canPreviewApp() -> Bool
    func refreshUserInfo()
}

final class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {
    typealias Factory =
        AppSessionRefreshTimerFactory &
        AppStateManagerFactory &
        CoreAlertServiceFactory &
        NavigationServiceFactory &
        ProfileManagerFactory &
        ReviewFactory &
        UpdateCheckerFactory &
        VpnAuthenticationFactory &
        VpnGatewayFactory

    private let factory: Factory

    lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private var navService: NavigationService? {
        factory.makeNavigationService()
    }

    private lazy var refreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    private lazy var vpnAuthentication: VpnAuthentication = factory.makeVpnAuthentication()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var review: Review = factory.makeReview()
    @Dependency(\.searchStorage) private var searchStorage
    @Dependency(\.networking) private var networking
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.unauthKeychain) private var unauthKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.vpnApiClient) private var vpnApiClient
    lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()

    @Dependency(\.announcementRefresher) var announcementRefresher: AnnouncementRefresher
    @Dependency(\.planService) private var planService
    @Dependency(\.planServiceV2) private var planServiceV2
    @Dependency(\.propertiesManager) private var propertiesManager

    var sessionStatus: SessionStatus = .undetermined {
        didSet {
            log.info(.init(stringLiteral: "Session status is now \(sessionStatus)"), category: .app)
            log.info("Session status is now \(sessionStatus)", category: .app)
        }
    }

    private var refreshUserInfoTask: Task<Void, Error>?
    private var paymentTransactionEvents: Task<Void, Never>?

    // MARK: - Init

    init(factory: Factory) {
        self.factory = factory
        super.init(factory: factory)

        AppEvent.appStateManagerStateChange.subscribe(self, selector: #selector(updateState))
        AppEvent.userEngagedWithUpsellAlert.subscribe(self, selector: #selector(userEngagedWithUpsell))
        AppEvent.hermes.subscribe(self, selector: #selector(updateWiregardConfig))

        if !FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
            let planService = CorePlanService()
            // this workaround is only needed due to old PaymentsV1 logic
            planService.alertService = alertService
            prepareDependencies {
                $0.planService = planService
            }
        }
    }

    // MARK: - Beginning of the login logic.

    @MainActor
    override func attemptSilentLogIn() async throws {
        guard authKeychain.fetch()?.username != nil else {
            throw CommonVpnError.userCredentialsMissing
        }
        do {
            @Dependency(\.userSettingsClient) var userSettingsClient
            propertiesManager.userSettings = try await userSettingsClient.fetchUserSettings(authCredentials: nil)
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

        let shouldRefreshServers = await !serverManager.shouldFetchFullServerList
        let appState = await appStateManager.stateThreadSafe
        let properties: VpnProperties
        do {
            properties = try await vpnApiClient.vpnProperties(
                isDisconnected: appState.isDisconnected,
                lastKnownLocation: propertiesManager.userLocation,
                serversAccordingToTier: shouldRefreshServers
            )
        } catch {
            log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])

            // only fail if there is a major reason
            if isServerRepositoryEmpty || propertiesManager.userLocation?.ip == nil {
                throw error
            }

            try await refreshVpnAuthCertificate()
            serverRepository.setMetadata("0", for: .consecutiveSuccessfulRefreshes)
            return
        }

        let credentials = properties.vpnCredentials
        vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
        review.update(plan: credentials.planName)

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
        try await refreshVpnAuthCertificate()
    }

    @MainActor
    func refreshVpnAuthCertificate() async throws {
        guard loggedIn else {
            log.info("Not refreshing vpn certificate - client not logged in")
            return
        }

        guard case .certificate = propertiesManager.vpnProtocol.authenticationType else {
            log.info("Not refreshing vpn certificate - cert auth not in use")
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            self.vpnAuthentication.refreshCertificates { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error) where error is ProviderMessageError:
                    // The vpn isn't connected yet, which means the extension hasn't been
                    // launched (if it's used at all for the user's preferred protocol)
                    // and the provider can't refresh the certificate.
                    // Fake success and the extension can handle refresh itself once we're connected.
                    continuation.resume()
                case .failure(AuthenticationRemoteClientError.needNewKeys):
                    // The network extension tried to refresh certificates, but the server responded saying
                    // that new keys needed regenerating. VpnAuthentication has deleted the keys, and now
                    // we just need to attempt to reconnect, since that will generate new keys for us.
                    executeOnUIThread {
                        AppEvent.needsReconnect.post()
                        continuation.resume()
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // swiftlint:disable function_body_length
    private func retrievePropertiesAndLogIn() async throws {
        @Dependency(\.serverManager) var serverManager
        let appState = await appStateManager.stateThreadSafe
        let shouldRefreshServersAccordingToTier = !serverManager.shouldFetchFullServerList

        // Get VPN properties from API and save them
        do {
            let properties = try await vpnApiClient.vpnProperties(
                isDisconnected: appState.isDisconnected,
                lastKnownLocation: propertiesManager.userLocation,
                serversAccordingToTier: shouldRefreshServersAccordingToTier
            )

            let credentials = properties.vpnCredentials
            vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
            review.update(plan: credentials.planName)

            // populate (possibly) updated userTier
            @Shared(.userTier) var userTier
            $userTier.withLock { $0 = credentials.maxTier }

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
            if let clientConfig = properties.clientConfig {
                // Apply Hermes DNS configuration when storing WireGuard config
                propertiesManager.wireguardConfig = clientConfig.wireGuardConfig.refreshConfig()
                propertiesManager.smartProtocolConfig = clientConfig.smartProtocolConfig
                propertiesManager.maintenanceServerRefreshIntereval = clientConfig.serverRefreshInterval
                propertiesManager.featureFlags = clientConfig.featureFlags
                propertiesManager.ratingSettings = clientConfig.ratingSettings
                review.update(configuration: ReviewConfiguration(settings: clientConfig.ratingSettings))
                @Dependency(\.serverChangeStorage) var storage
                storage.config = clientConfig.serverChangeConfig
            }
            if let streamingServices = properties.streamingResponse {
                propertiesManager.streamingServices = streamingServices.streamingServices
                propertiesManager.streamingResourcesUrl = streamingServices.resourceBaseURL
            }
            if propertiesManager.featureFlags.pollNotificationAPI {
                announcementRefresher.tryRefreshing()
            }

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

        // In case we are connected to VPN, but can't get auth info from `appStateManager` nor
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
        profileManager.refreshProfiles()

        // Refresh certificate but don't log out in case of an error.
        try await refreshVpnAuthCertificate()
        if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
            try await planServiceV2.fetchAppleStatus()
        } else {
            try await planService.updateServicePlans()
        }

        startListeningToPaymentTransactionEvents()
    }

    // swiftlint:enable function_body_length

    private func resolveActiveSession() async throws {
        await MainActor.run { AppEvent.sessionManagerSessionRefreshed.post() }

        guard await appStateManager.stateThreadSafe.isConnected else {
            return // Success
        }

        guard let activeUsername = await appStateManager.stateThreadSafe.descriptor?.username,
              let vpnCredentials = try? vpnKeychain.fetch() else {
            throw CommonVpnError.fetchSession // Error
        }

        let usernameFromAppStateManager = activeUsername.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar)
        let usernameFromKeychain = vpnCredentials.name.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar)
        if usernameFromAppStateManager == usernameFromKeychain {
            return // Success
        }
        log.debug("VPN usernames don't match", category: .app, metadata: ["usernameFromAppStateManager": "\(usernameFromAppStateManager)", "usernameFromKeychain": "\(usernameFromKeychain)"])

        // Info: Before refactoring, this method could finish without calling either a success
        // or a failure. Now if finishes successfully in case ifs above haven't finished
        // execution earlier.
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
        let group = DispatchGroup()
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
        review.clear()

        // HACK - remove this after PaymentsV2 migration has finished, and replace it with planServiceV2.clear()
        AppEvent.userDidLogOut.post()

        @Dependency(\.serverManager) var serverManager
        serverManager.purgeAllServers()

        let vpnAuthenticationTimeoutInSeconds = 2
        group.enter()
        vpnAuthentication.clearEverything {
            group.leave()
        }
        _ = group.wait(timeout: .now() + .seconds(vpnAuthenticationTimeoutInSeconds))

        propertiesManager.logoutCleanup()

        networking.apiService.acquireSessionIfNeeded { _ in }
        paymentTransactionEvents?.cancel()
        paymentTransactionEvents = nil
    }

    // End of the logout logic

    // MARK: -

    // Updates the status of the app, including refreshing the VpnGateway object if the VPN creds change
    private func setAndNotify(for state: SessionStatus, reason: String?) {
        guard !loggedIn else { return }

        sessionStatus = state
        if state == .established {
            loggedIn = true
            propertiesManager.hasConnected = true
            DispatchQueue.main.async { [weak self] in AppEvent.sessionManagerSessionChanged.post(self?.vpnGateway) }
        } else if state == .notEstablished {
            // Clear auth token and vpn creds to ensure they won't be used
            logOutCleanup()
            DispatchQueue.main.async { AppEvent.sessionManagerSessionChanged.post(reason) }
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
            let upsellSuccessData = UpsellData(
                modalSource: modalSource,
                newPlanName: downgradeInfo.to.planName,
                reference: "VPNINTROPRICE2024",
                flowType: .external
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
            modalSource: event.modalSource,
            newPlanName: event.newPlanName,
            reference: event.offerReference,
            flowType: event.flowType
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

// MARK: - Review

extension AppSessionManagerImplementation {
    @objc
    private func updateState(_ notification: Notification) {
        guard let state = notification.object as? AppState else {
            return
        }

        switch state {
        case .connected:
            review.connected()
        case .disconnected:
            review.disconnect()
        case .error, .aborted(userInitiated: false):
            review.connectionFailed()
        default:
            break
        }
    }
}

// MARK: - WireGuard config

import Hermes

private extension WireguardConfig {
    func refreshConfig() -> WireguardConfig {
        @Dependency(\.hermesClient) var hermesClient
        @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider

        let hermesIsEnabled: Bool = hermesClient.isEnabled().wrappedValue
        let hermesIsAllowed = featureAuthorizerProvider.authorizer(for: HermesFeature.self)().isAllowed

        var hermesResolvers: [HermesResolver] = [.proton]
        if hermesIsEnabled, hermesIsAllowed {
            hermesResolvers.insert(contentsOf: hermesClient.activeHermesResolvers().wrappedValue, at: 0)
        }
        return .init(
            defaultUdpPorts: defaultUdpPorts,
            defaultTcpPorts: defaultTcpPorts,
            defaultTlsPorts: defaultTlsPorts,
            dns: hermesResolvers.map(\.location)
        )
    }
}

extension AppSessionManagerImplementation {
    @objc
    private func updateWiregardConfig(_: Notification) {
        propertiesManager.wireguardConfig = propertiesManager.wireguardConfig.refreshConfig()
    }
}
