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
    
    func attemptRememberLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logOut(force: Bool)
    func logOut()
    func replyToApplicationShouldTerminate()
}

class AppSessionManagerImplementation: AppSessionManager {

    typealias Factory = VpnApiServiceFactory & AuthApiServiceFactory & AppStateManagerFactory & FirewallManagerFactory & NavigationServiceFactory & VpnKeychainFactory & PropertiesManagerFactory & ServerStorageFactory & VpnGatewayFactory & CoreAlertServiceFactory & AppSessionRefreshTimerFactory & AnnouncementRefresherFactory
    private let factory: Factory
    
    internal lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var authApiService: AuthApiService = factory.makeAuthApiService()
    private lazy var vpnApiService: VpnApiService = factory.makeVpnApiService()
    private lazy var firewallManager: FirewallManager = factory.makeFirewallManager()
    private var navService: NavigationService? {
        return factory.makeNavigationService()
    }
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var propertiesManager = factory.makePropertiesManager()
    private lazy var serverStorage: ServerStorage = factory.makeServerStorage()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var refreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    private lazy var announcementRefresher: AnnouncementRefresher = factory.makeAnnouncementRefresher()

    let sessionChanged = Notification.Name("AppSessionManagerSessionChanged")
    var sessionStatus: SessionStatus = .notEstablished
    var loggedIn = false
    
    // AppSessionRefresher
    var lastDataRefresh: Date?
    var lastServerLoadsRefresh: Date?
    
    init(factory: Factory) {
        self.factory = factory
        self.propertiesManager.restoreStartOnBootStatus()
    }
    
    // MARK: - Beginning of the log in logic.
    func attemptRememberLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        guard AuthKeychain.fetch() != nil else {
            failure(ProtonVpnErrorConst.userCredentialsMissing)
            return
        }
        
        success()
        
        retrievePropertiesAndLogIn(success: success, failure: { error in
            DispatchQueue.main.async { failure(error) }
        })
    }
    
    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        authApiService.authenticate(username: username, password: password, success: { [weak self] authCredentials in
            do {
                try AuthKeychain.store(authCredentials)
            } catch {
                DispatchQueue.main.async { failure(ProtonVpnError.keychainWriteFailed) }
                return
            }
            self?.retrievePropertiesAndLogIn(success: success, failure: failure)
            
        }, failure: { error in
            PMLog.ET("Failed to obtain user's auth credentials: \(error)")
            DispatchQueue.main.async { failure(error) }
        })
    }
    
    private func retrievePropertiesAndLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        vpnApiService.vpnProperties(lastKnownIp: propertiesManager.userIp, success: { [weak self] properties in
            guard let `self` = self else { return }
            
            if let credentials = properties.vpnCredentials {
                self.vpnKeychain.store(vpnCredentials: credentials)
            }
            self.serverStorage.store(properties.serverModels)
            
            if self.appStateManager.state.isDisconnected {
                self.propertiesManager.userIp = properties.ip
            }
            self.propertiesManager.featureFlags = properties.clientConfig.featureFlags
            self.propertiesManager.maintenanceServerRefreshIntereval = properties.clientConfig.serverRefreshInterval
            self.resolveActiveSession(success: { [weak self] in
                self?.setAndNotify(for: .established)
                ProfileManager.shared.refreshProfiles()
                success()
            }, failure: { error in
                self.logOutCleanup()
                failure(error)
            })
        }, failure: { [weak self] error in
            PMLog.D("Failed to obtain user's VPN properties: \(error.localizedDescription)", level: .error)
            guard let `self` = self, // only fail if there is a major reason
                  !self.serverStorage.fetch().isEmpty,
                  self.propertiesManager.userIp != nil,
                  !(error is KeychainError) else {
                failure(error)
                return
            }
            
            self.setAndNotify(for: .established)
            ProfileManager.shared.refreshProfiles()
            success()
        })
        
        if propertiesManager.featureFlags.isAnnouncementOn {
            announcementRefresher.refresh()
        }
    }
    
    private func resolveActiveSession(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        disconnectIfNeeded()
        
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
            
            let confirmationClosure: () -> Void = { [weak self] in
                guard let `self` = self else { return }
                if self.appStateManager.state.isConnected {
                    self.appStateManager.disconnect { success() }
                    return
                }
                success()
            }
            
            let cancelationClosure: () -> Void = {
                failure(ProtonVpnErrorConst.vpnSessionInProgress)
            }
            
            let alert = ActiveSessionWarningAlert(confirmHandler: confirmationClosure, cancelHandler: cancelationClosure)
            alertService.push(alert: alert)
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert(confirmHandler: {
                failure(ProtonVpnError.fetchSession)
            }))
            return
        }
    }
    
    private func disconnectIfNeeded() {
        do {
            let vpnCredentials = try vpnKeychain.fetch()

            if case AppState.connected(_) = appStateManager.state {
                if let server = appStateManager.activeConnection()?.server {
                    if server.tier > vpnCredentials.maxTier {
                        appStateManager.disconnect()
                    }
                }
            }
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }
    
    // MARK: - Log out
    func logOut(force: Bool) {
        loggedIn = false
        
        if force || !appStateManager.state.isConnected {
            confirmLogout()
        } else {
            let logoutAlert = LogoutWarningLongAlert(confirmHandler: { [confirmLogout] in
                confirmLogout()
            })
            alertService.push(alert: logoutAlert)
        }
    }
    
    func logOut() {
        logOut(force: false)
    }
    
    private func confirmLogout() {
        switch appStateManager.state {
        case .connecting:
            appStateManager.cancelConnectionAttempt { [logoutRoutine] in logoutRoutine() }
        default:
            appStateManager.disconnect { [logoutRoutine] in logoutRoutine() }
        }
    }
    
    private func logoutRoutine() {
        setAndNotify(for: .notEstablished)
        logOutCleanup()
    }
    
    private func logOutCleanup() {
        refreshTimer.stop()
        loggedIn = false
        
        AuthKeychain.clear()
        vpnKeychain.clear()
        
        propertiesManager.logoutCleanup()
    }
    // End of the logout logic
    // MARK: -
    
    private func setAndNotify(for state: SessionStatus) {
        guard !loggedIn else { return }
        
        loggedIn = true
        sessionStatus = state
        
        var object: Any?
        if state == .established {
            object = factory.makeVpnGateway()
            
            // No need to connect twice on macOS 10.15+
            if #available(OSX 10.15, *) {
                PropertiesManager().hasConnected = true
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: self.sessionChanged, object: object)
        }
        
        refreshTimer.start()
    }
    
    // MARK: - AppDelegate quit behaviour
    
    func replyToApplicationShouldTerminate() {
        guard sessionStatus == .established && !appStateManager.state.isSafeToEnd && !propertiesManager.rememberLoginAfterUpdate else {
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }
        
        let confirmationClosure: () -> Void = { [weak self] in
            self?.appStateManager.disconnect {
                self?.firewallManager.disableFirewall {
                    DispatchQueue.main.async {
                        NSApp.reply(toApplicationShouldTerminate: true)
                    }
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

extension AppSessionManagerImplementation: AppSessionRefresher {
    
    @objc func refreshData() {
        lastDataRefresh = Date()
        attemptRememberLogIn(success: {}, failure: { [unowned self] error in
            PMLog.D("Failed to reistablish vpn credentials: \(error.localizedDescription)", level: .error)
            
            let error = error as NSError
            switch error.code {
            case ApiErrorCode.apiVersionBad, ApiErrorCode.appVersionBad:
                self.alertService.push(alert: AppUpdateRequiredAlert(error as! ApiError))
            default:
                break // ignore failures
            }
        })
    }
    
    @objc func refreshServerLoads() {
        guard loggedIn else { return }
        lastServerLoadsRefresh = Date()
        
        vpnApiService.loads(lastKnownIp: propertiesManager.userIp, success: { properties in
            self.serverStorage.update(continuousServerProperties: properties)
            
        }, failure: { error in
            PMLog.D("Error received: \(error)", level: .error)
        })
    }
    
}
