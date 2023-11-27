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
    func refreshVpnAuthCertificate() async throws -> Void
    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func finishLogin(authCredentials: AuthCredentials, completion: @escaping (Result<(), Error>) -> Void)
    func logOut(force: Bool, reason: String?)
    
    func loadDataWithoutFetching() -> Bool
    func loadDataWithoutLogin(success: @escaping () -> Void, failure: @escaping (Error) -> Void)
    func canPreviewApp() -> Bool
}

extension AppSessionManager {
    func refreshVpnAuthCertificate() async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            refreshVpnAuthCertificate(success: {
                continuation.resume()
            }, failure: { error in
                continuation.resume(throwing: error)
            })
        }
    }
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
        guard authKeychain.username != nil else {
            completion(.failure(ProtonVpnError.userCredentialsMissing))
            return
        }

        retrievePropertiesAndLogIn(success: { completion(.success) }, failure: { error in
            DispatchQueue.main.async { completion(.failure(error)) }
        })
    }
    
    func finishLogin(authCredentials: AuthCredentials, completion: @escaping (Result<(), Error>) -> Void) {
        Task {
            do {
                try await authKeychain.store(authCredentials)
                await unauthKeychain.clear()
            } catch {
                await MainActor.run {
                    completion(.failure(ProtonVpnError.keychainWriteFailed))
                }
                return
            }
            await MainActor.run {
                retrievePropertiesAndLogIn(success: { [weak self] in
                    self?.checkForSubuserWithoutSessions(completion: completion)
                }, failure: { error in
                    log.error("Failed to obtain user's auth credentials", category: .user, metadata: ["error": "\(error)"])
                    completion(.failure(error))
                })
            }
        }
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
        Task {
            let shouldRefreshServers = await shouldRefreshServersAccordingToUserTier
            let appState = await appStateManager.stateThreadSafe

            vpnApiService.vpnProperties(
                isDisconnected: appState.isDisconnected,
                lastKnownLocation: propertiesManager.userLocation,
                serversAccordingToTier: shouldRefreshServers
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
                            keepStalePaidServers: shouldRefreshServers && credentials.maxTier == CoreAppConstants.VpnTiers.free
                        )
                    } else {
                        self.serverStorage.store(properties.serverModels)
                    }

                    self.propertiesManager.userLocation = properties.location

                    self.refreshPartners(ifUnknownPartnerLogicalExistsIn: properties.serverModels) {
                        executeOnUIThread {
                            self.resolveActiveSession(success: {
                                self.refreshVpnAuthCertificate(success: success, failure: failure)
                                Task { await self.successfulConsecutiveSessionRefreshes.increment() }
                            }, failure: { error in
                                self.logOutCleanup()
                                Task { await self.successfulConsecutiveSessionRefreshes.reset() }
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
                    Task { await self.successfulConsecutiveSessionRefreshes.reset() }
                }
            }
        }
    }

    @available(*, renamed: "refreshVpnAuthCertificate()")
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
        Task {
            let appState = await appStateManager.stateThreadSafe
            let shouldRefreshServers = await shouldRefreshServersAccordingToUserTier

            // Get VPN properties from API and save them
            do {
                let properties = try await vpnApiService.vpnProperties(
                    isDisconnected: appState.isDisconnected,
                    lastKnownLocation: propertiesManager.userLocation,
                    serversAccordingToTier: shouldRefreshServers
                )

                if let credentials = properties.vpnCredentials {
                    self.vpnKeychain.storeAndDetectDowngrade(vpnCredentials: credentials)
                    self.review.update(plan: credentials.accountPlan.rawValue)
                    self.serverStorage.store(
                        properties.serverModels,
                        keepStalePaidServers: shouldRefreshServers && credentials.maxTier == CoreAppConstants.VpnTiers.free
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

            } catch {
                // In case getting vpn properties fails, we don't log user out in all cases. Instead
                // check if we can continue.
                // If user has the list of servers and IP is already saved, we can continue
                // and update vpnProperties later.
                // Also the error has to be not keychain related, because if there is a problem with
                // the keychain, use most probably will not be able to use API nor VPN connection.
                log.error("Failed to obtain user's VPN properties", category: .app, metadata: ["error": "\(error)"])
                let models = self.serverStorage.fetch()
                guard !models.isEmpty, // only fail if there is a major reason
                      self.propertiesManager.userLocation?.ip != nil,
                      !(error is LegacyCommon.KeychainError) else {

                    failure(error)
                    return
                }
            }

            // In case we are connected to VPN, but can't get auth info from `appStateManager` nor
            // from `vpnKeychain`, we fail miserably and log out.
            do {
                try await self.resolveActiveSession()

            } catch {
                self.logOutCleanup()
                await self.successfulConsecutiveSessionRefreshes.reset()
                failure(error)
                return
            }

            setAndNotify(for: .established, reason: nil)
            profileManager.refreshProfiles()

            // Refresh certificate but don't log out in case of an error.
            do {
                try await refreshVpnAuthCertificate()
            } catch {
                failure(error)
                return
            }

            await successfulConsecutiveSessionRefreshes.increment()

            do {
                try await planService.updateServicePlans()
            } catch {
                failure(error)
                return
            }

            success()
        }
    }
    // swiftlint:enable function_body_length
    
    @available(*, renamed: "resolveActiveSession()")
    private func resolveActiveSession(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        Task {
            do {
                try await resolveActiveSession()
                success()
            } catch {
                failure(error)
            }
        }
    }

    private func resolveActiveSession() async throws {
        Task { @MainActor in NotificationCenter.default.post(Notification(name: self.sessionRefreshed, object: nil)) }

        guard await appStateManager.stateThreadSafe.isConnected else {
            return // Success
        }

        guard let activeUsername = await appStateManager.stateThreadSafe.descriptor?.username,
                let vpnCredentials = try? vpnKeychain.fetch() else {
            throw ProtonVpnError.fetchSession // Error
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
        let group = DispatchGroup()
        refreshTimer.stop()
        loggedIn = false
        group.enter()
        Task {
            await authKeychain.clear()
            group.leave()
        }
        group.wait()
        vpnKeychain.clear()
        announcementRefresher.clear()
        planService.clear()
        searchStorage.clear()
        review.clear()

        FeatureFlagsRepository.shared.resetFlags()
        
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
        
        refreshTimer.start(now: false)
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
        guard authKeychain.username != nil else {
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
