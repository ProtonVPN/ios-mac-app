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

import Cocoa
import Dependencies

import ProtonCoreFeatureFlags
import ProtonCoreUtilities

import Ergonomics
import LegacyCommon
import VPNShared

enum SessionStatus {
    case notEstablished
    case established
}

protocol AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager
}

protocol AppSessionManager {
    var sessionStatus: SessionStatus { get set }
    var loggedIn: Bool { get }

    func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void)
    func refreshVpnAuthCertificate() async throws
    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logOut(force: Bool, reason: String?)
    func logOut()

    func replyToApplicationShouldTerminate()
}

final class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {

    typealias Factory = VpnApiServiceFactory &
                        AppStateManagerFactory &
                        VpnKeychainFactory &
                        PropertiesManagerFactory &
                        ServerStorageFactory &
                        VpnGatewayFactory &
                        CoreAlertServiceFactory &
                        NetworkingFactory &
                        AppSessionRefreshTimerFactory &
                        AnnouncementRefresherFactory &
                        VpnAuthenticationFactory &
                        ProfileManagerFactory &
                        AppCertificateRefreshManagerFactory &
                        SystemExtensionManagerFactory &
                        PlanServiceFactory &
                        AuthKeychainHandleFactory &
                        UnauthKeychainHandleFactory
    private let factory: Factory

    internal lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    @MainActor var appState: AppState { appStateManager.state }

    private lazy var networking: Networking = factory.makeNetworking()
    private lazy var appSessionRefreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    private lazy var announcementRefresher: AnnouncementRefresher = factory.makeAnnouncementRefresher()
    private lazy var vpnAuthentication: VpnAuthentication = factory.makeVpnAuthentication()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var appCertificateRefreshManager: AppCertificateRefreshManager = factory.makeAppCertificateRefreshManager()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var unauthKeychain: UnauthKeychainHandle = factory.makeUnauthKeychainHandle()

    var sessionStatus: SessionStatus = .notEstablished {
        didSet { loggedIn = sessionStatus == .established }
    }

    init(factory: Factory) {
        self.factory = factory
        super.init(factory: factory)
        self.propertiesManager.restoreStartOnBootStatus()

        planService.updateCountriesCount()
    }

    // MARK: public log in interface (completion handlers)

    override func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        // Invoke async implementation
        executeOnUIThread(
            attemptLogin,
            success: { completion(.success) },
            failure: { completion(.failure($0)) }
        )
    }

    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        // Invoke async implementation
        executeOnUIThread({ try await self.attemptLogin(with: authCredentials) }, success: success, failure: failure)
    }

    // MARK: private log in implementation (async)

    private func attemptLogin() async throws {
        guard authKeychain.fetch() != nil else {
            throw ProtonVpnError.userCredentialsMissing
        }
        try await finishLogin()
    }

    private func attemptLogin(with authCredentials: AuthCredentials) async throws {
        do {
            try authKeychain.store(authCredentials)
            unauthKeychain.clear()
        } catch {
            throw ProtonVpnError.keychainWriteFailed
        }

        try await finishLogin()
    }

    @MainActor
    private func finishLogin() async throws {
        try await retrieveProperties()
        try await refreshVpnAuthCertificate()

        if sessionStatus == .notEstablished {
            sessionStatus = .established
            propertiesManager.hasConnected = true
            post(notification: SessionChanged(data: .established(gateway: self.factory.makeVpnGateway())))
        }

        appSessionRefreshTimer.start(now: false)
        profileManager.refreshProfiles()
        await appCertificateRefreshManager.planNextRefresh()
    }

    @MainActor
    func refreshVpnAuthCertificate() async throws {
        if !loggedIn {
            return
        }

        _ = try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.vpnAuthentication.refreshCertificates(completion: continuation.resume(with:))
        }
    }

    private func retrieveProperties() async throws {
        guard let properties = try await getVPNProperties() else {
            await successfulConsecutiveSessionRefreshes.reset()
            return
        }

        let credentials = properties.vpnCredentials
        vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
        await self.serverStorage.store(
            properties.serverModels,
            keepStalePaidServers: shouldRefreshServersAccordingToUserTier && credentials.maxTier == CoreAppConstants.VpnTiers.free
        )

        if await appState.isDisconnected {
            propertiesManager.userLocation = properties.location
        }
        propertiesManager.userRole = properties.userRole
        propertiesManager.userAccountCreationDate = properties.userCreateTime
        if let clientConfig = properties.clientConfig {
            propertiesManager.openVpnConfig = clientConfig.openVPNConfig
            propertiesManager.wireguardConfig = clientConfig.wireGuardConfig
            propertiesManager.smartProtocolConfig = clientConfig.smartProtocolConfig
            propertiesManager.featureFlags = clientConfig.featureFlags
            propertiesManager.maintenanceServerRefreshIntereval = clientConfig.serverRefreshInterval
            propertiesManager.ratingSettings = clientConfig.ratingSettings
            @Dependency(\.serverChangeStorage) var storage
            storage.config = clientConfig.serverChangeConfig
        }
        if propertiesManager.featureFlags.pollNotificationAPI {
            Task { @MainActor in
                self.announcementRefresher.tryRefreshing()
            }
        }

        do {
            try await resolveActiveSession()
        } catch {
            logOutCleanup()
            await successfulConsecutiveSessionRefreshes.reset()
            throw error
        }

        await successfulConsecutiveSessionRefreshes.increment()
    }

    /// Ignore errors unless one of the following is true:
    /// - API returns `ProtonVpnError.subuserWithoutSessions`
    /// - Server storage is empty or user IP is not known
    /// - We hit a keychain error
    private func getVPNProperties() async throws -> VpnProperties? {
        let isDisconnected = await appState.isDisconnected
        let location = propertiesManager.userLocation

        do {
            return try await vpnApiService.vpnProperties(
                isDisconnected: isDisconnected,
                lastKnownLocation: location,
                serversAccordingToTier: shouldRefreshServersAccordingToUserTier
            )
        } catch ProtonVpnError.subuserWithoutSessions {
            log.error("User with insufficient sessions detected. Throwing an error instead of logging in.", category: .app)
            logOutCleanup()
            throw ProtonVpnError.subuserWithoutSessions
        } catch {
            log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])
            if serverStorage.fetch().isEmpty || self.propertiesManager.userLocation?.ip == nil {
                throw error
            }
        }
        return nil
    }

    private func resolveActiveSession() async throws {
        guard await appState.isConnected else {
            return
        }

        guard let activeUsername = await appState.descriptor?.username else {
            throw ProtonVpnError.fetchSession
        }

        guard let vpnCredentials = try? vpnKeychain.fetch() else {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            throw ProtonVpnError.fetchSession
        }

        if activeUsername.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar)
            == vpnCredentials.name.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar) {
            return
        }

        try await confirmAndDisconnectActiveSession()
    }

    private func confirmAndDisconnectActiveSession() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let alert = ActiveSessionWarningAlert(confirmHandler: { [weak self] in
                guard let self = self else {
                    return
                }

                if self.appStateManager.state.isConnected {
                    self.appStateManager.disconnect { continuation.resume() }
                    return
                }

                continuation.resume()
            }, cancelHandler: {
                continuation.resume(throwing: ProtonVpnError.vpnSessionInProgress)
            })
            self.alertService.push(alert: alert)
        }
    }

    // MARK: - Log out

    func logOut() {
        logOut(force: false, reason: nil)
    }

    func logOut(force: Bool, reason: String?) {
        switch appStateManager.state {
        case .connected:
            confirmLogout(showAlert: !force) {
                self.appStateManager.disconnect { self.logoutRoutine(reason: reason) }
            }
        case .connecting:
            appStateManager.cancelConnectionAttempt { self.logoutRoutine(reason: reason) }
        default:
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
        sessionStatus = .notEstablished
        post(notification: SessionChanged(data: .lost(reason: reason)))
        appSessionRefreshTimer.start(now: false)
        logOutCleanup()
    }

    private func logOutCleanup() {
        let group = DispatchGroup()
        appSessionRefreshTimer.stop()
        
        if let userId = authKeychain.userId {
            FeatureFlagsRepository.shared.resetFlags(for: userId)
            FeatureFlagsRepository.shared.clearUserId()
        }
        
        authKeychain.clear()
        vpnKeychain.clear()
        announcementRefresher.clear()

        let vpnAuthenticationTimeoutInSeconds = 2

        group.enter()
        vpnAuthentication.clearEverything {
            group.leave()
        }
        _ = group.wait(timeout: .now() + .seconds(vpnAuthenticationTimeoutInSeconds))

        propertiesManager.logoutCleanup()

        networking.apiService.acquireSessionIfNeeded { _ in }
    }

    // End of the logout logic

    private func post(notification: any TypedNotification) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(notification, object: self)
        }
    }

    // MARK: - AppDelegate quit behaviour

    func replyToApplicationShouldTerminate() {
        if propertiesManager.uninstallSysexesOnTerminate {
            _ = sysexManager.uninstallAll(userInitiated: false)
        }

        guard sessionStatus == .established && !appStateManager.state.isSafeToEnd && !propertiesManager.rememberLoginAfterUpdate else {
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }

        let confirmationClosure: () -> Void = { [weak self] in
            self?.appStateManager.disconnect {
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
        }

        // ensure application data hasn't been cleared
        @Dependency(\.defaultsProvider) var provider
        guard provider.getDefaults().bool(forKey: AppConstants.UserDefaults.launchedBefore) else {
            confirmationClosure()
            return
        }

        let cancelationClosure: () -> Void = { NSApp.reply(toApplicationShouldTerminate: false) }

        let alert = QuitWarningAlert(confirmHandler: confirmationClosure, cancelHandler: cancelationClosure)
        alertService.push(alert: alert)
    }

    // MARK: User plan changed (before refreshing data)
    override func userPlanChanged(_ notification: Notification) {
        if let downgradeInfo = notification.object as? VpnDowngradeInfo,
           downgradeInfo.from.maxTier < downgradeInfo.to.maxTier {

            // At some point it may be possible to plumb the modal source through from the redirect deep link.
            // For now we will leave it nil and let the telemetry service take its best guess.
            let modalSource: UpsellEvent.ModalSource? = nil
            NotificationCenter.default.post(
                name: .userCompletedUpsellAlertJourney,
                object: (modalSource, downgradeInfo.to.accountPlan.rawValue)
            )
        }

        super.userPlanChanged(notification) // refreshes data
    }
}

struct SessionChanged: TypedNotification {
    static let name = Notification.Name("AppSessionManagerSessionChanged")
    let data: SessionChangeData

    enum SessionChangeData {
        case established(gateway: VpnGatewayProtocol)
        case lost(reason: String?)
    }
}
