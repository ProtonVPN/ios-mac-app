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
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import vpncore

import UIKit

// Login state
enum SessionStatus {
    
    case notEstablished
    case established
}

protocol AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager
}

protocol AppSessionManager {
    var vpnGateway: VpnGatewayProtocol? { get }
    var sessionStatus: SessionStatus { get set }
    var loggedIn: Bool { get }
    
    var sessionChanged: Notification.Name { get }
    
    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func logOut(force: Bool)
    
    func attemptDataRefreshWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func loadDataWithoutFetching() -> Bool
    func loadDataWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func refreshData()
    func canPreviewApp() -> Bool
}

class AppSessionManagerImplementation: AppSessionManager {
    
    typealias Factory = VpnApiServiceFactory & AuthApiServiceFactory & AppStateManagerFactory & VpnKeychainFactory & PropertiesManagerFactory & ServerStorageFactory & VpnGatewayFactory & CoreAlertServiceFactory & NavigationServiceFactory & StoreKitManagerFactory & AlamofireWrapperFactory
    private let factory: Factory
    
    internal lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var authApiService: AuthApiService = factory.makeAuthApiService()
    private lazy var vpnApiService: VpnApiService = factory.makeVpnApiService()
    private var navService: NavigationService? {
        return factory.makeNavigationService()
    }
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var propertiesManager = factory.makePropertiesManager()
    private lazy var serverStorage: ServerStorage = factory.makeServerStorage()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var storeKitManager: StoreKitManager = factory.makeStoreKitManager()
    private lazy var alamofireWrapper: AlamofireWrapper = factory.makeAlamofireWrapper()
    var vpnGateway: VpnGatewayProtocol?
    
    let sessionChanged = Notification.Name("AppSessionManagerSessionChanged")
    let sessionRefreshed = Notification.Name("AppSessionManagerSessionRefreshed")
    let logInWarning = Notification.Name("AppSessionManagerLogInWarning")
    let upgradeRequired = Notification.Name("AppSessionManagerUpgradeRequired")
    
    let refreshRate: TimeInterval = 3 * 60
    var lastRefresh = Date()
    
    var sessionStatus: SessionStatus = .notEstablished

    var loginTimer: Timer?
    var loggedIn = false
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    // MARK: - Beginning of the login logic.
    func attemptDataRefreshWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        guard AuthKeychain.fetch() != nil else {
            failure(ProtonVpnErrorConst.userCredentialsMissing)
            return
        }
        
        retrievePropertiesAndLogIn(success: success, failure: { error in
            DispatchQueue.main.async { failure(error) }
        })
    }
    
    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        authApiService.authenticate(username: username, password: password, success: { [weak self] authCredentials in
            AuthKeychain.store(authCredentials)
            self?.storeKitManager.processAllTransactions { // this should run after every login
                self?.retrievePropertiesAndLogIn(success: success, failure: failure)
            }
        }, failure: { error in
            PMLog.ET("Failed to obtain user's auth credentials: \(error.localizedDescription)")
            DispatchQueue.main.async { failure(error) }
        })
    }
    
    func loadDataWithoutFetching() -> Bool {
        guard !self.serverStorage.fetch().isEmpty,
              self.propertiesManager.userIp != nil else {
            return false
        }
        
        // swiftlint:disable unused_optional_binding
        if let _ = try? vpnKeychain.fetch() {
            setAndNotify(for: .established)
        } else {
            setAndNotify(for: .notEstablished)
        }
        // swiftlint:enable unused_optional_binding
        
        return true
    }
    
    func canPreviewApp() -> Bool {
        guard !self.serverStorage.fetch().isEmpty, self.propertiesManager.userIp != nil else {
            return false
        }
        return true
    }
    
    func loadDataWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        vpnApiService.vpnProperties(lastKnownIp: propertiesManager.userIp, success: { [weak self] properties in
            guard let `self` = self else { return }
            
            if let credentials = properties.vpnCredentials {
                self.vpnKeychain.store(vpnCredentials: credentials)
            }
            self.serverStorage.store(properties.serverModels)
            self.propertiesManager.userIp = properties.ip
            
            self.resolveActiveSession(success: {
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
            
                success()
        })
    }
    
    private func retrievePropertiesAndLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        // update IAPs
        ServicePlanDataServiceImplementation.shared.updateCurrentSubscription { [weak self] in
            self?.storeKitManager.subscribeToPaymentQueue()
        }
        
        vpnApiService.vpnProperties(lastKnownIp: propertiesManager.userIp, success: { [weak self] properties in
            guard let `self` = self else { return }
            
            if let credentials = properties.vpnCredentials {
                self.vpnKeychain.store(vpnCredentials: credentials)
            }
            self.serverStorage.store(properties.serverModels)
            
            self.propertiesManager.userIp = properties.ip
            
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
    }
    
    private func resolveActiveSession(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        disconnectIfNeeded()
        
        let refreshNotification = Notification(name: sessionRefreshed, object: nil)
        DispatchQueue.main.async { NotificationCenter.default.post(refreshNotification) }
        
        guard appStateManager.state.isConnected else {
            success()
            return
        }
        
        guard let activeUsername = appStateManager.state.descriptor?.username, let vpnCredentials = try? vpnKeychain.fetch() else {
            failure(ProtonVpnError.fetchSession)
            return
        }
        
        if activeUsername == vpnCredentials.name {
            success()
            return
        }
        
    }
    
    private func disconnectIfNeeded() {
        guard let vpnCredentials = try? vpnKeychain.fetch() else { return }

        if case AppState.connected(_) = appStateManager.state {
            if let server = appStateManager.activeServer {
                if server.tier > vpnCredentials.maxTier {
                    appStateManager.disconnect()
                }
            }
        }
    }
    
    // MARK: - Log out
    func logOut(force: Bool = false) {
        let logOutRoutine: () -> Void = { [weak self] in
            self?.loggedIn = false
            self?.logOutCleanup()
            self?.setAndNotify(for: .notEstablished)
        }
        
        if appStateManager.state.isSafeToEnd {
            logOutRoutine()
            return
        }
        
        let confirmationClosure: () -> Void = { [weak self] in
            guard let `self` = self else { return }
            if self.appStateManager.state.isConnected {
                self.appStateManager.disconnect { logOutRoutine() }
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
        loginTimer?.invalidate()
        loginTimer = nil
        loggedIn = false
        
        AuthKeychain.clear()
        vpnKeychain.clear()
        
        propertiesManager.logoutCleanup()        
        alamofireWrapper.setHumanVerification(token: nil)
    }
    // MARK: - End of the logout logic
    
    // Updates the status of the app, including refreshing the VpnGateway object if the VPN creds change
    private func setAndNotify(for state: SessionStatus) {
        guard !loggedIn else { return }
        
        sessionStatus = state
        
        var object: VpnGatewayProtocol?
        if state == .established {
            loggedIn = true
            object = factory.makeVpnGateway()            
            propertiesManager.hasConnected = true
        } else if state == .notEstablished {
            // Clear auth token and vpn creds to ensure they won't be used
            logOutCleanup()
        }
        vpnGateway = object
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: self.sessionChanged, object: object)
        }
        
        scheduleRefreshes()
    }
    
    // MARK: - Refresh
    private func scheduleRefreshes() {
        if loginTimer == nil || !loginTimer!.isValid {
            loginTimer = Timer.scheduledTimer(timeInterval: refreshRate, target: self, selector: #selector(refreshData), userInfo: nil, repeats: true)
        }
    }
    
    func stopRefreshingIfInactive() {
        if UIApplication.shared.applicationState != .active {
            loginTimer?.invalidate()
            loginTimer = nil
        }
    }
    
    @objc func refreshData() {
        lastRefresh = Date()
        if loggedIn {
            attemptDataRefreshWithoutLogin(success: {}, failure: { error in
                PMLog.D("Failed to reestablish vpn credentials: \(error.localizedDescription)", level: .error)
                
                let error = error as NSError
                switch error.code {
                default:
                    break // ignore most failures, allowing the user to continue using the app
                }
            })
        } else {
            loadDataWithoutLogin(success: {}, failure: { _ in })
        }
    }
}
