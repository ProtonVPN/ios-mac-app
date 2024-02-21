//
//  AppDelegate.swift
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

// System frameworks
import UIKit
import Foundation

// Third-party dependencies
import Dependencies
import TrustKit

// Core dependencies
import ProtonCoreAccountRecovery
import ProtonCoreCryptoVPNPatchedGoImplementation
import ProtonCoreEnvironment
import ProtonCoreFeatureFlags
import ProtonCoreFeatureSwitch
import ProtonCoreLog
import ProtonCoreNetworking
import ProtonCoreObservability
import ProtonCorePushNotifications
import ProtonCoreServices
import ProtonCoreUIFoundations

// Local dependencies
import Domain
import LegacyCommon
import Logging
import PMLogger
import VPNShared
import VPNAppCore


public let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger")

#if !REDESIGN
class AppDelegate: UIResponder {
    private static let acceptedDeepLinkChallengeInterval: TimeInterval = 10

    @Dependency(\.defaultsProvider) var defaultsProvider
    @Dependency(\.cryptoService) var cryptoService

    private let container = DependencyContainer.shared
    private lazy var vpnManager: VpnManagerProtocol = container.makeVpnManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = container.makeVpnKeychain()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var planService: PlanService = container.makePlanService()
    private lazy var pushNotificationService = container.makePushNotificationService()
}
#else
class AppDelegate: UIResponder {
    private static let acceptedDeepLinkChallengeInterval: TimeInterval = 10

    @Dependency(\.defaultsProvider) var defaultsProvider
    @Dependency(\.cryptoService) var cryptoService

    private let container = DependencyContainer.shared
    private lazy var vpnManager: VpnManagerProtocol = container.makeVpnManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = container.makeVpnKeychain()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var planService: PlanService = container.makePlanService()
}
#endif

// MARK: - UIApplicationDelegate
extension AppDelegate: UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupCoreIntegration(launchOptions: launchOptions)
        setupLogsForApp()
        setupDebugHelpers()

        SiriHelper.quickConnectIntent = QuickConnectIntent()
        SiriHelper.disconnectIntent = DisconnectIntent()
#if !REDESIGN // moved over to ProtonVPNApp init
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")
#endif
        LegacyDefaultsMigration.migrateLargeData(from: defaultsProvider.getDefaults())

        // Protocol check is placed here for parity with MacOS
        adjustGlobalProtocolIfNecessary()

        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.sentry) {
            SentryHelper.setupSentry(
                dsn: ObfuscatedConstants.sentryDsniOS,
                isEnabled: { [weak self] in
                    self?.container.makeTelemetrySettings().telemetryCrashReports ?? false
                },
                getUserId: { [weak self] in
                    self?.container.makeAuthKeychainHandle().userId
                }
            )
        }
        
        AnnouncementButtonViewModel.shared = container.makeAnnouncementButtonViewModel()

        vpnManager.whenReady(queue: DispatchQueue.main) {
            self.navigationService.launched()
        }
        
        container.makeMaintenanceManagerHelper().startMaintenanceManager()
                
        _ = container.makeDynamicBugReportManager() // Loads initial bug report config and sets up a timer to refresh it daily.

        container.applicationDidFinishLaunching()
        return true
    }
        
    private func setupDebugHelpers() {
        #if FREQUENT_AUTH_CERT_REFRESH
        CertificateConstants.certificateDuration = "30 minutes"
        #endif
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        appStateManager.refreshState()
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle Siri intents
        let prefix = "com.protonmail.vpn."
        guard userActivity.activityType.hasPrefix(prefix) else {
            return false
        }
        
        let action = String(userActivity.activityType.dropFirst(prefix.count))

        // We know the action is verified because the user activity has our prefix.
        let verified = true
        return handleAction(action, verified: verified)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            log.error("Invalid URL", category: .app)
            return false
        }

        let verified = isVerifiedUrl(components)
        return handleAction(host, verified: verified)
    }

    func isVerifiedUrl(_ components: URLComponents) -> Bool {
        guard let queryItems = components.queryItems,
              let t = queryItems.first(where: { $0.name == "t" })?.value,
              var timestamp = Int(t) else {
            return false
        }

        let timestampDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let interval = Date().timeIntervalSince(timestampDate)
        guard interval < Self.acceptedDeepLinkChallengeInterval else {
            return false
        }

        let algorithm = CryptoConstants.widgetChallengeAlgorithm
        guard let s = queryItems.first(where: { $0.name == "s" })?.value?.data(using: .utf8),
           let a = queryItems.first(where: { $0.name == "a" })?.value,
               a == algorithm.stringValue,
           let signature = Data(base64Encoded: s) else {
            return false
        }

        let challenge = withUnsafeBytes(of: &timestamp) { Data($0) }

        do {
            let publicKey = try vpnKeychain.fetchWidgetPublicKey()
            if try cryptoService.verify(signature: signature, of: challenge, with: publicKey, using: algorithm) {
                return true
            }
        } catch {
            log.error("Couldn't verify url: \(error)")
        }

        log.error("Verification of url failed: \(components)")
        return false
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        log.info("applicationDidEnterBackground", category: .os)
        container.makePropertiesManager().lastTimeForeground = Date()
        vpnManager.appBackgroundStateDidChange(isBackground: true)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        log.info("applicationDidBecomeActive", category: .os)
        vpnManager.appBackgroundStateDidChange(isBackground: false)

        // If the app was on a closed state, we'll have to wait for the configuration to be established
        appStateManager.onVpnStateChanged = { [weak self] state in
            self?.appStateManager.onVpnStateChanged = nil
            self?.checkStuckConnection(state)
        }
        
        // Otherwise just  check directly  the connection
        self.checkStuckConnection(vpnManager.state)
        
        // Refresh API announcements
        let announcementRefresher = self.container.makeAnnouncementRefresher() // This creates refresher that is persisted in DI container
        if propertiesManager.featureFlags.pollNotificationAPI, container.makeAuthKeychainHandle().username != nil {
            announcementRefresher.tryRefreshing()
        }
        Task { @MainActor in
            try? await container.makeAppSessionManager().refreshVpnAuthCertificate()
            container.makeReview().activated()
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        pushNotificationService.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        pushNotificationService.didFailToRegisterForRemoteNotifications(withError: error)
    }

    private func setupLogsForApp() {
        let logFile = self.container.makeLogFileManager().getFileUrl(named: AppConstants.Filenames.appLogFilename)

        let fileLogHandler = FileLogHandler(logFile)
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        let multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        LoggingSystem.bootstrap { _ in return multiplexLogHandler }
    }
}

fileprivate extension AppDelegate {
    
    // MARK: - Private

    func handleAction(_ action: String, verified: Bool = false) -> Bool {
        switch action {
            
        case URLConstants.deepLinkLoginAction:
            DispatchQueue.main.async { [weak self] in
                self?.navigationService.presentWelcome(initialError: nil)                
            }
            
        case URLConstants.deepLinkConnectAction:
            // Action may only come from a trusted source
            guard verified else { return false }

            // Extensions requesting a connection should set a connection request first
            navigationService.vpnGateway.quickConnect(trigger: .widget)
            NotificationCenter.default.addObserver(self, selector: #selector(stateDidUpdate), name: VpnGateway.connectionChanged, object: nil)
            navigationService.presentStatusViewController()
            
        case URLConstants.deepLinkDisconnectAction:
            // Action may only come from a trusted source
            guard verified else { return false }

            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.widget))
            navigationService.vpnGateway.disconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }

        case URLConstants.deepLinkRefresh, URLConstants.deepLinkRefreshAccount:
            guard container.makeAuthKeychainHandle().username != nil else {
                log.debug("User is not logged in, not refreshing user data", category: .app)
                return false
            }

            log.debug("App activated with the refresh url, refreshing data", category: .app)
            container.makeAppSessionManager().attemptSilentLogIn { result in
                switch result {
                case .success:
                    log.debug("User data refreshed after url activation", category: .app)
                case let .failure(error):
                    log.error("User data failed to refresh after url activation", category: .app, metadata: ["error": "\(error)"])
                }
            }
            NotificationCenter.default.post(name: PropertiesManager.announcementsNotification, object: nil)

        default:
            log.error("Invalid url action", category: .app, metadata: ["action": "\(action)"])
            return false
        }
        
        return true
    }
    
    @objc func stateDidUpdate() {
        switch appStateManager.state {
        case .connected:
            NotificationCenter.default.removeObserver(self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            }
        case .connecting, .preparingConnection:
            // wait
            return
        default:
            NotificationCenter.default.removeObserver(self)
            return
        }
    }
    
    func checkStuckConnection( _ state: VpnState) {

        let propertiesManager = container.makePropertiesManager()
        guard case VpnState.connecting(_) = state else {
            propertiesManager.lastTimeForeground = nil
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Time.waitingTimeForConnectionStuck) {
            guard case .connecting = self.vpnManager.state else {
                propertiesManager.lastTimeForeground = nil
                return
            }
            
            let lastTime = propertiesManager.lastTimeForeground
            
            if lastTime == nil || lastTime!.timeIntervalSinceNow > AppConstants.Time.timeForForegroundStuck {
                self.container.makeVpnGateway().quickConnect(trigger: .quick)
            }
                
            propertiesManager.lastTimeForeground = nil
        }
    }

    private func adjustGlobalProtocolIfNecessary() {
        if propertiesManager.connectionProtocol.isDeprecated {
            propertiesManager.connectionProtocol = .smartProtocol
        }
    }
}

extension AppDelegate {
    private func setupCoreIntegration(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        injectDefaultCryptoImplementation()

        let doh = container.makeDoHVPN()
        if doh.defaultHost.contains("black") {
            PMLog.setEnvironment(environment: "black")
        } else {
            PMLog.setEnvironment(environment: "production")
        }

        ProtonCoreLog.PMLog.callback = { (message, level) in
            switch level {
            case .debug, .info, .trace, .warn:
                log.debug("\(message)", category: .core)
            case .error, .fatal:
                log.error("\(message)", category: .core)
            }
        }

        let apiService = container.makeNetworking().apiService
        apiService.acquireSessionIfNeeded { result in
            switch result {
            case .success(.sessionAlreadyPresent(let authCredential)), .success(.sessionFetchedAndAvailable(let authCredential)):
                FeatureFlagsRepository.shared.setApiService(apiService)
                
                if !authCredential.userID.isEmpty {
                    FeatureFlagsRepository.shared.setUserId(authCredential.userID)
                }

                Task {
                    try await FeatureFlagsRepository.shared.fetchFlags()
                }
            case .failure(let error):
                log.error("acquireSessionIfNeeded didn't succeed and therefore feature flags didn't get fetched", category: .api, event: .response, metadata: ["error": "\(error)"])
            default:
                break
            }
        }
        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)

        // For now, the Push Notification part of Account Recovery is not ready, so we won't even be registering
        if false && FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.accountRecovery) {
            pushNotificationService.setup()

            let vpnHandler = AccountRecoveryHandler()
            vpnHandler.handler = { _ in
                // for now, for all notification types, we take the same action
                self.navigationService.presentAccountRecoveryViewController()
                return .success(())
            }

            pushNotificationService.registerHandler(vpnHandler, forType: NotificationType.accountRecoveryInitiated)
        }
    }
}
