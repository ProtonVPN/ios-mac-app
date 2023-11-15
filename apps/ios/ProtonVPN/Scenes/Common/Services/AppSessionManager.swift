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

import LegacyCommon
import UIKit
import Foundation
import Dependencies
import Search
import Review
import VPNShared
import ProtonCoreFeatureFlags

enum SessionStatus {
    
    case notEstablished
    case established
}

protocol AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager
}

protocol AppSessionManager {
    var vpnGateway: VpnGatewayProtocol { get }
    var sessionStatus: SessionStatus { get set }
    var loggedIn: Bool { get }
    
    var sessionChanged: Notification.Name { get }
    var dataReloaded: Notification.Name { get }

    func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void)
    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func finishLogin(authCredentials: AuthCredentials, completion: @escaping (Result<(), Error>) -> Void)
    func logOut(force: Bool, reason: String?)
    
    func loadDataWithoutFetching() -> Bool
    func loadDataWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func canPreviewApp() -> Bool
}

class AppSessionManagerImplementation: AppSessionRefresherImplementation, AppSessionManager {
    
    typealias Factory = VpnApiServiceFactory &
                        AppStateManagerFactory &
                        VpnKeychainFactory &
                        PropertiesManagerFactory &
                        ServerStorageFactory &
                        VpnGatewayFactory &
                        CoreAlertServiceFactory &
                        NavigationServiceFactory &
                        NetworkingFactory &
                        AppSessionRefreshTimerFactory &
                        AnnouncementRefresherFactory &
                        VpnAuthenticationFactory &
                        PlanServiceFactory &
                        ProfileManagerFactory &
                        SearchStorageFactory &
                        ReviewFactory &
                        AuthKeychainHandleFactory &
                        UnauthKeychainHandleFactory

    private let factory: Factory

    internal lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private var navService: NavigationService? {
        return factory.makeNavigationService()
    }

    private lazy var networking: Networking = factory.makeNetworking()
    private lazy var refreshTimer: AppSessionRefreshTimer = factory.makeAppSessionRefreshTimer()
    private lazy var announcementRefresher: AnnouncementRefresher = factory.makeAnnouncementRefresher()
    private lazy var vpnAuthentication: VpnAuthentication = factory.makeVpnAuthentication()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var searchStorage: SearchStorage = factory.makeSearchStorage()
    private lazy var review: Review = factory.makeReview()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var unauthKeychain: UnauthKeychainHandle = factory.makeUnauthKeychainHandle()
    lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()

    let sessionChanged = Notification.Name("AppSessionManagerSessionChanged")
    let sessionRefreshed = Notification.Name("AppSessionManagerSessionRefreshed")
    let dataReloaded = Notification.Name("AppSessionManagerDataReloaded")
        
    var sessionStatus: SessionStatus = .notEstablished
    
    init(factory: Factory) {
        self.factory = factory
        super.init(factory: factory)

        planService.delegate = self

        NotificationCenter.default.addObserver(forName: .AppStateManager.stateChange, object: nil, queue: nil, using: updateState)
    }
    
    // MARK: - Beginning of the login logic.
    override func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        guard authKeychain.fetch() != nil else {
            completion(.failure(ProtonVpnError.userCredentialsMissing))
            return
        }

        retrievePropertiesAndLogIn(success: { completion(.success) }, failure: { error in
            DispatchQueue.main.async { completion(.failure(error)) }
        })
    }
    
    func finishLogin(authCredentials: AuthCredentials, completion: @escaping (Result<(), Error>) -> Void) {
        do {
            try authKeychain.store(authCredentials)
            unauthKeychain.clear()
        } catch {
            DispatchQueue.main.async {
                completion(.failure(ProtonVpnError.keychainWriteFailed))
            }
            return
        }
       
        retrievePropertiesAndLogIn(success: { [weak self] in
            self?.checkForSubuserWithoutSessions(completion: completion)
        }, failure: { error in
            log.error("Failed to obtain user's auth credentials", category: .user, metadata: ["error": "\(error)"])
            completion(.failure(error))
        })
    }
    
    func loadDataWithoutFetching() -> Bool {
        let models = serverStorage.fetch()
        guard !models.isEmpty,
              self.propertiesManager.userLocation?.ip != nil else {
            return false
        }

        if (try? vpnKeychain.fetchCached()) != nil {
            setAndNotify(for: .established, reason: nil)
        } else {
            setAndNotify(for: .notEstablished, reason: nil)
        }
        return true
    }
    
    func canPreviewApp() -> Bool {
        let models = serverStorage.fetch()
        guard !models.isEmpty, self.propertiesManager.userLocation?.ip != nil else {
            return false
        }
        return true
    }
    
    func loadDataWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        vpnApiService.vpnProperties(
            isDisconnected: appStateManager.state.isDisconnected,
            lastKnownLocation: propertiesManager.userLocation,
            serversAccordingToTier: shouldRefreshServersAccordingToUserTier
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case let .success(properties):
                if let credentials = properties.vpnCredentials {
                    self.vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
                    self.review.update(plan: credentials.accountPlan.rawValue)
                    self.serverStorage.store(
                        properties.serverModels,
                        keepStalePaidServers: shouldRefreshServersAccordingToUserTier && credentials.maxTier == CoreAppConstants.VpnTiers.free
                    )
                } else {
                    self.serverStorage.store(properties.serverModels)
                }

                self.propertiesManager.userLocation = properties.location

                self.refreshPartners(ifUnknownPartnerLogicalExistsIn: properties.serverModels) {
                    executeOnUIThread {
                        self.resolveActiveSession(success: {
                            self.refreshVpnAuthCertificate(success: success, failure: failure)
                            self.successfulConsecutiveSessionRefreshes += 1
                        }, failure: { error in
                            self.logOutCleanup()
                            self.successfulConsecutiveSessionRefreshes = 0
                            failure(error)
                        })
                    }
                }
            case let .failure(error):
                log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])
                let models = self.serverStorage.fetch()
                guard !models.isEmpty, // only fail if there is a major reason
                      self.propertiesManager.userLocation?.ip != nil,
                      !(error is LegacyCommon.KeychainError) else {
                        failure(error)
                        return
                }

                self.refreshVpnAuthCertificate(success: success, failure: failure)
                self.successfulConsecutiveSessionRefreshes = 0
            }
        }
    }

    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        guard loggedIn else {
            log.info("Not refreshing vpn certificate - client not logged in")
            success()
            return
        }

        guard case .certificate = propertiesManager.vpnProtocol.authenticationType else {
            log.info("Not refreshing vpn certificate - cert auth not in use")
            success()
            return
        }

        self.vpnAuthentication.refreshCertificates { result in
            switch result {
            case .success:
                success()
            case let .failure(error) where error is ProviderMessageError:
                // The vpn isn't connected yet, which means the extension hasn't been
                // launched (if it's used at all for the user's preferred protocol)
                // and the provider can't refresh the certificate.
                // Fake success and the extension can handle refresh itself once we're connected.
                success()
            case .failure(AuthenticationRemoteClientError.needNewKeys):
                // The network extension tried to refresh certificates, but the server responded saying
                // that new keys needed regenerating. VpnAuthentication has deleted the keys, and now
                // we just need to attempt to reconnect, since that will generate new keys for us.
                executeOnUIThread {
                    NotificationCenter.default.post(name: VpnGateway.needsReconnectNotification, object: nil)
                    success()
                }
            case let .failure(error):
                failure(error)
            }
        }
    }

    private func retrievePropertiesAndLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        let group = DispatchGroup()

        var vpnPropertiesError: Error?
        group.enter()
        vpnApiService.vpnProperties(
            isDisconnected: appStateManager.state.isDisconnected,
            lastKnownLocation: propertiesManager.userLocation,
            serversAccordingToTier: shouldRefreshServersAccordingToUserTier
        ) { [weak self] result in
            let fail = { (error: Error) in
                vpnPropertiesError = error
                group.leave()
            }
            let ok = {
                group.leave()
            }

            guard let self = self else {
                ok()
                return
            }

            switch result {
            case let .success(properties):
                if let credentials = properties.vpnCredentials {
                    self.vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
                    self.review.update(plan: credentials.accountPlan.rawValue)
                    self.serverStorage.store(
                        properties.serverModels,
                        keepStalePaidServers: shouldRefreshServersAccordingToUserTier && credentials.maxTier == CoreAppConstants.VpnTiers.free
                    )
                } else {
                    self.serverStorage.store(properties.serverModels)
                }
                self.propertiesManager.userRole = properties.userRole
                self.propertiesManager.userAccountCreationDate = properties.userCreateTime
                self.propertiesManager.userLocation = properties.location
                if let clientConfig = properties.clientConfig {
                    self.propertiesManager.openVpnConfig = clientConfig.openVPNConfig
                    self.propertiesManager.wireguardConfig = clientConfig.wireGuardConfig
                    self.propertiesManager.smartProtocolConfig = clientConfig.smartProtocolConfig
                    self.propertiesManager.maintenanceServerRefreshIntereval = clientConfig.serverRefreshInterval
                    self.propertiesManager.featureFlags = clientConfig.featureFlags
                    self.propertiesManager.ratingSettings = clientConfig.ratingSettings
                    self.review.update(configuration: Configuration(settings: clientConfig.ratingSettings))
                    @Dependency(\.serverChangeStorage) var storage
                    storage.config = clientConfig.serverChangeConfig
                }
                if self.propertiesManager.featureFlags.pollNotificationAPI {
                    self.announcementRefresher.tryRefreshing()
                }

                self.resolveActiveSession(success: { [weak self] in
                    self?.setAndNotify(for: .established, reason: nil)
                    self?.profileManager.refreshProfiles()
                    self?.refreshVpnAuthCertificate(success: ok, failure: fail)
                    self?.successfulConsecutiveSessionRefreshes += 1
                }, failure: { error in
                    fail(error)
                    self.logOutCleanup()
                    self.successfulConsecutiveSessionRefreshes = 0
                })
            case let .failure(error):
                log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])
                let models = self.serverStorage.fetch()
                guard !models.isEmpty, // only fail if there is a major reason
                      self.propertiesManager.userLocation?.ip != nil,
                      !(error is LegacyCommon.KeychainError) else {
                          fail(error)
                          return
                }

                self.setAndNotify(for: .established, reason: nil)
                self.profileManager.refreshProfiles()
                self.refreshVpnAuthCertificate(success: ok, failure: fail)
                self.successfulConsecutiveSessionRefreshes = 0
            }
        }

        var plansError: Error?
        group.enter()
        planService.updateServicePlans { result in
            switch result {
            case .success:
                break
            case let .failure(error):
                plansError = error
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let error = vpnPropertiesError ?? plansError {
                failure(error)
                return
            }

            success()
        }
    }
    // swiftlint:enable function_body_length
    
    private func resolveActiveSession(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
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
        
        if activeUsername.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar)
            == vpnCredentials.name.removeSubstring(startingWithCharacter: VpnManagerConfiguration.configConcatChar) {
            success()
        }
    }
    
    private func checkForSubuserWithoutSessions(completion: @escaping (Result<(), Error>) -> Void) {
        guard let credentials = try? self.vpnKeychain.fetchCached(),
            credentials.needConnectionAllocation else {
            completion(.success)
            return
        }

        log.error("User with insufficient sessions detected. Throwing an error instead of logging in.", category: .app)
        logOutCleanup()
        completion(.failure(ProtonVpnError.subuserWithoutSessions))
    }
    
    // MARK: - Log out
    func logOut(force: Bool = false, reason: String?) {
        let logOutRoutine: () -> Void = { [weak self] in
            self?.loggedIn = false
            self?.logOutCleanup()
            self?.setAndNotify(for: .notEstablished, reason: reason)
        }
        
        if appStateManager.state.isSafeToEnd {
            logOutRoutine()
            return
        }
        
        let confirmationClosure: () -> Void = { [weak self] in
            guard let self = self else {
                return
            }

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
        refreshTimer.stop()
        loggedIn = false
        authKeychain.clear()
        vpnKeychain.clear()
        announcementRefresher.clear()
        planService.clear()
        searchStorage.clear()
        review.clear()

        FeatureFlagsRepository.shared.resetFlags()
        
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
    // MARK: -
    
    // Updates the status of the app, including refreshing the VpnGateway object if the VPN creds change
    private func setAndNotify(for state: SessionStatus, reason: String?) {
        guard !loggedIn else { return }
        
        sessionStatus = state
        if state == .established {
            loggedIn = true
            propertiesManager.hasConnected = true
            postNotification(name: sessionChanged, object: vpnGateway)
        } else if state == .notEstablished {
            // Clear auth token and vpn creds to ensure they won't be used
            logOutCleanup()
            postNotification(name: sessionChanged, object: reason)
        }
        
        refreshTimer.start()
    }

    private func postNotification(name: Notification.Name, object: Any?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: object)
        }
    }
}

// MARK: - Plan change
extension AppSessionManagerImplementation: PlanServiceDelegate {
    func paymentTransactionDidFinish(modalSource: UpsellEvent.ModalSource?, newPlanName: String?) {
        guard authKeychain.fetch() != nil else {
            return
        }

        // Note: Do not async this part, we don't want it to race with retrieving the new properties below.
        NotificationCenter.default.post(name: .userCompletedUpsellAlertJourney, object: (modalSource, newPlanName))

        log.debug("Reloading data after plan purchase", category: .app)
        retrievePropertiesAndLogIn(success: { [dataReloaded] in
            NotificationCenter.default.post(name: dataReloaded, object: nil)
        }, failure: { error in
            log.error("Data reload failed after plan purchase", category: .app, metadata: ["error": "\(error)"])
        })
    }
}

// MARK: - Review
extension AppSessionManagerImplementation {
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
