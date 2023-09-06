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
import LegacyCommon
import VPNShared
import ProtonCoreUtilities

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
    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logOut(force: Bool, reason: String?)
    func logOut()

    func replyToApplicationShouldTerminate()
}

final class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {

    typealias Factory = VpnApiServiceFactory &
                        AppStateManagerFactory &
                        NavigationServiceFactory &
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
    private var navService: NavigationService? { return factory.makeNavigationService() }

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
        executeOnUIThread(attemptLogin, success: { completion(.success) }, failure: { completion(.failure($0)) })
    }

    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        // Invoke async implementation
        executeOnUIThread(refreshVpnAuthCertificate, success: success, failure: failure)
    }

    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        // Invoke async implementation
        executeOnUIThread({ try await self.attemptLogin(with: authCredentials) }, success: success, failure: failure)
    }

    // MARK: private log in implementation (async)

    private func attemptLogin() async throws {
        if authKeychain.fetch() == nil {
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
        try checkForSubuserWithoutSessions()
        try await refreshVpnAuthCertificate()

        if sessionStatus == .notEstablished {
            sessionStatus = .established
            propertiesManager.hasConnected = true
            post(notification: SessionChanged(data: .established(gateway: self.factory.makeVpnGateway())))
        }

        appSessionRefreshTimer.start()
        profileManager.refreshProfiles()
        appCertificateRefreshManager.planNextRefresh()
    }

    private func refreshVpnAuthCertificate() async throws {
        if !loggedIn {
            return
        }

        _ = try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.vpnAuthentication.refreshCertificates { result in continuation.resume(with: result) }
        }
    }

    private func checkForSubuserWithoutSessions() throws {
        if let credentials = try? self.vpnKeychain.fetchCached(),
           credentials.needConnectionAllocation {
            log.error("User with insufficient sessions detected. Throwing an error instead of logging in.", category: .app)
            logOutCleanup()
            throw ProtonVpnError.subuserWithoutSessions
        }
    }

    private func retrieveProperties() async throws {
        guard let properties = try await getVPNProperties() else {
            successfulConsecutiveSessionRefreshes = 0
            return
        }

        if let credentials = properties.vpnCredentials {
            vpnKeychain.store(vpnCredentials: credentials)
            self.serverStorage.store(
                properties.serverModels,
                keepStalePaidServers: shouldRefreshServersAccordingToUserTier && credentials.maxTier == CoreAppConstants.VpnTiers.free
            )
        } else {
            self.serverStorage.store(properties.serverModels)
        }

        if await appState.isDisconnected {
            propertiesManager.userLocation = properties.location
        }
        propertiesManager.openVpnConfig = properties.clientConfig.openVPNConfig
        propertiesManager.wireguardConfig = properties.clientConfig.wireGuardConfig
        propertiesManager.smartProtocolConfig = properties.clientConfig.smartProtocolConfig
        propertiesManager.userRole = properties.userRole
        propertiesManager.featureFlags = properties.clientConfig.featureFlags
        propertiesManager.maintenanceServerRefreshIntereval = properties.clientConfig.serverRefreshInterval
        propertiesManager.ratingSettings = properties.clientConfig.ratingSettings
        @Dependency(\.serverChangeStorage) var storage
        storage.config = properties.clientConfig.serverChangeConfig
        if propertiesManager.featureFlags.pollNotificationAPI {
            DispatchQueue.main.async { self.announcementRefresher.tryRefreshing() }
        }

        do {
            try await resolveActiveSession()
        } catch {
            logOutCleanup()
            successfulConsecutiveSessionRefreshes = 0
            throw error
        }

        successfulConsecutiveSessionRefreshes += 1
    }

    private func getVPNProperties() async throws -> VpnProperties? {
        let isDisconnected = await appState.isDisconnected
        let location = propertiesManager.userLocation

        do {
            return try await vpnApiService.vpnProperties(
                isDisconnected: isDisconnected,
                lastKnownLocation: location,
                serversAccordingToTier: shouldRefreshServersAccordingToUserTier
            )
        } catch {
            log.error("Failed to obtain user's VPN properties: \(error.localizedDescription)", category: .app)
            if serverStorage.fetch().isEmpty, self.propertiesManager.userLocation?.ip == nil, (error is KeychainError) {
                // only throw if there is a major reason
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
        appSessionRefreshTimer.start()
        logOutCleanup()
    }

    private func logOutCleanup() {
        appSessionRefreshTimer.stop()

        authKeychain.clear()
        vpnKeychain.clear()
        announcementRefresher.clear()

        let vpnAuthenticationTimeoutInSeconds = 2
        let group = DispatchGroup()
        group.enter()
        vpnAuthentication.clearEverything {
            group.leave()
        }
        _ = group.wait(timeout: .now() + .seconds(vpnAuthenticationTimeoutInSeconds))

        propertiesManager.logoutCleanup()

        networking.apiService.acquireSessionIfNeeded { _ in }
    }

    // End of the logout logic

    private func post(notification: any StrongNotification) {
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
}

struct SessionChanged: StrongNotification {
    static var name: Notification.Name { Notification.Name("AppSessionManagerSessionChanged") }
    let data: SessionChangeData

    enum SessionChangeData {
        case established(gateway: VpnGatewayProtocol)
        case lost(reason: String?)
    }
}
