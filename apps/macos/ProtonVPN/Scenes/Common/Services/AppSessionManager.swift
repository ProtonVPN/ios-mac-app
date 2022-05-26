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
import vpncore

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
    
    var sessionChanged: Notification.Name { get }
    
    func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void)
    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logOut(force: Bool, reason: String?)
    func logOut()
    
    func replyToApplicationShouldTerminate()
}

final class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {

    typealias Factory = VpnApiServiceFactory & AppStateManagerFactory & NavigationServiceFactory & VpnKeychainFactory & PropertiesManagerFactory & ServerStorageFactory & VpnGatewayFactory & CoreAlertServiceFactory & AppSessionRefreshTimerFactory & AnnouncementRefresherFactory & VpnAuthenticationFactory & ProfileManagerFactory & AppCertificateRefreshManagerFactory & SystemExtensionManagerFactory & PlanServiceFactory
    private let factory: Factory
    
    internal lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private var navService: NavigationService? {
        return factory.makeNavigationService()
    }

    private lazy var refreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    private lazy var announcementRefresher: AnnouncementRefresher = factory.makeAnnouncementRefresher()
    private lazy var vpnAuthentication: VpnAuthentication = factory.makeVpnAuthentication()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var appCertificateRefreshManager: AppCertificateRefreshManager = factory.makeAppCertificateRefreshManager()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()

    let sessionChanged = Notification.Name("AppSessionManagerSessionChanged")
    var sessionStatus: SessionStatus = .notEstablished
    
    init(factory: Factory) {
        self.factory = factory
        super.init(factory: factory)
        self.propertiesManager.restoreStartOnBootStatus()

        planService.updateCountriesCount()
    }
    
    // MARK: - Beginning of the log in logic.
    override func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        guard AuthKeychain.fetch() != nil else {
            completion(.failure(ProtonVpnErrorConst.userCredentialsMissing))
            return
        }
        
        let failureWrapper = { error in
            DispatchQueue.main.async { completion(.failure(error)) }
        }
        
        retrieveProperties(success: { [weak self] in
            self?.finishLogin(success: {
                // Only put this in silent login logic, to approximate only showing this modal to existing users.
                if self?.propertiesManager.newBrandModalShown != true {
                    self?.alertService.push(alert: NewBrandAlert())
                    self?.propertiesManager.newBrandModalShown = true
                }

                completion(.success)
            }, failure: failureWrapper)
        }, failure: failureWrapper)
    }

    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        guard loggedIn else {
            success()
            return
        }

        self.vpnAuthentication.refreshCertificates { result in
            switch result {
            case .success:
                success()
            case let .failure(error):
                failure(error)
            }
        }
    }

    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        do {
            try AuthKeychain.store(authCredentials)
        } catch {
            DispatchQueue.main.async { failure(ProtonVpnError.keychainWriteFailed) }
            return
        }
        retrieveProperties(success: { [weak self] in
            self?.checkForSubuserWithoutSessions(success: { [weak self] in
                self?.finishLogin(success: success, failure: failure)
            }, failure: failure)
        }, failure: failure)
    }
    
    private func retrieveProperties(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        vpnApiService.vpnProperties(isDisconnected: appStateManager.state.isDisconnected,
                                    lastKnownLocation: propertiesManager.userLocation) { [weak self] result in
            switch result {
            case let .success(properties):
                guard let self = self else {
                    return
                }

                if let credentials = properties.vpnCredentials {
                    self.vpnKeychain.store(vpnCredentials: credentials)
                }
                self.serverStorage.store(properties.serverModels)

                if self.appStateManager.state.isDisconnected {
                    self.propertiesManager.userLocation = properties.location
                }
                self.propertiesManager.openVpnConfig = properties.clientConfig.openVPNConfig
                self.propertiesManager.wireguardConfig = properties.clientConfig.wireGuardConfig
                self.propertiesManager.smartProtocolConfig = properties.clientConfig.smartProtocolConfig
                self.propertiesManager.streamingServices = properties.streamingResponse?.streamingServices ?? [:]
                self.propertiesManager.streamingResourcesUrl = properties.streamingResponse?.resourceBaseURL
                self.propertiesManager.featureFlags = properties.clientConfig.featureFlags
                self.propertiesManager.maintenanceServerRefreshIntereval = properties.clientConfig.serverRefreshInterval
                self.propertiesManager.ratingSettings = properties.clientConfig.ratingSettings
                if self.propertiesManager.featureFlags.pollNotificationAPI {
                    self.announcementRefresher.refresh()
                }

                self.resolveActiveSession(success: success, failure: { error in
                    self.logOutCleanup()
                    failure(error)
                })
            case let .failure(error):
                log.error("Failed to obtain user's VPN properties: \(error.localizedDescription)", category: .app)
                guard let self = self, // only fail if there is a major reason
                      !self.serverStorage.fetch().isEmpty,
                      self.propertiesManager.userLocation?.ip != nil,
                      !(error is KeychainError) else {

                    failure(error)
                    return
                }

                success()
            }
        }
    }
    
    private func finishLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        refreshVpnAuthCertificate(success: { [weak self] in
            self?.setAndNotify(for: .established, reason: nil)
            self?.profileManager.refreshProfiles()
            self?.appCertificateRefreshManager.planNextRefresh()
            success()
            
        }, failure: { error in
            failure(error)
        })
    }
    
    private func resolveActiveSession(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {

        DispatchQueue.main.async { [weak self] in
            self?.navService?.sessionRefreshed()
        }

        guard appStateManager.state.isConnected else {
            success()
            return
        }
        
        guard let activeUsername = appStateManager.state.descriptor?.username else {
            failure(ProtonVpnError.fetchSession)
            return
        }
        
        do {
            let vpnCredentials = try vpnKeychain.fetch()
            
            if activeUsername.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar)
                == vpnCredentials.name.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar) {
                success()
                return
            }
                        
            alertService.push(alert: ActiveSessionWarningAlert(confirmHandler: { [weak self] in
                guard let `self` = self else { return }
                if self.appStateManager.state.isConnected {
                    self.appStateManager.disconnect { success() }
                    return
                }
                success()
            }, cancelHandler: {
                failure(ProtonVpnErrorConst.vpnSessionInProgress)
            }))
        } catch {
            failure(ProtonVpnError.fetchSession)
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            return
        }
    }
    
    private func checkForSubuserWithoutSessions(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        guard let credentials = try? self.vpnKeychain.fetchCached() else {
            success()
            return
        }
        guard credentials.isSubuserWithoutSessions else {
            success()
            return
        }
        
        log.error("User with insufficient sessions detected. Throwing an error insted of login.", category: .app)
        logOutCleanup()
        failure(ProtonVpnError.subuserWithoutSessions)
    }
    
    // MARK: - Log out
    func logOut(force: Bool, reason: String?) {
        loggedIn = false
        
        if force || !appStateManager.state.isConnected {
            confirmLogout(reason: reason)
        } else {
            let logoutAlert = LogoutWarningLongAlert(confirmHandler: { [confirmLogout] in
                confirmLogout(reason)
            })
            alertService.push(alert: logoutAlert)
        }
    }
    
    func logOut() {
        logOut(force: false, reason: nil)
    }
    
    private func confirmLogout(reason: String?) {
        switch appStateManager.state {
        case .connecting:
            appStateManager.cancelConnectionAttempt { [logoutRoutine] in logoutRoutine(reason) }
        default:
            appStateManager.disconnect { [logoutRoutine] in logoutRoutine(reason) }
        }
    }
    
    private func logoutRoutine(reason: String?) {
        setAndNotify(for: .notEstablished, reason: reason)
        logOutCleanup()
    }
    
    private func logOutCleanup() {
        refreshTimer.stop()
        loggedIn = false
        
        AuthKeychain.clear()
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
    }
    // End of the logout logic
    // MARK: -
    
    private func setAndNotify(for state: SessionStatus, reason: String?) {
        guard !loggedIn else { return }

        sessionStatus = state
        
        var object: Any?
        if state == .established {
            loggedIn = true
            object = factory.makeVpnGateway()
            
            // No need to connect twice
            propertiesManager.hasConnected = true

            postNotification(name: sessionChanged, object: object)
        } else if state == .notEstablished {
            postNotification(name: sessionChanged, object: reason)
        }
        
        refreshTimer.start()
    }

    private func postNotification(name: Notification.Name, object: Any?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: object)
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
        guard Storage.userDefaults().bool(forKey: AppConstants.UserDefaults.launchedBefore) else {
            confirmationClosure()
            return
        }
        
        let cancelationClosure: () -> Void = { NSApp.reply(toApplicationShouldTerminate: false) }
        
        let alert = QuitWarningAlert(confirmHandler: confirmationClosure, cancelHandler: cancelationClosure)
        alertService.push(alert: alert)
    }
}
