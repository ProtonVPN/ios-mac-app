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
import TrustKit

// Core dependencies
import ProtonCore_Services
import ProtonCore_Log
import ProtonCore_UIFoundations
import ProtonCore_Environment
import ProtonCore_FeatureSwitch
import ProtonCore_Observability

// Local dependencies
import vpncore
import Logging
import PMLogger
import VPNShared

public let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger")

#if !REDESIGN
@UIApplicationMain
class AppDelegate: UIResponder {
    private let container = DependencyContainer.shared
    private lazy var vpnManager: VpnManagerProtocol = container.makeVpnManager()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var planService: PlanService = container.makePlanService()
}
#else
class AppDelegate: UIResponder {
    private let container = DependencyContainer.shared
    private lazy var vpnManager: VpnManagerProtocol = container.makeVpnManager()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var planService: PlanService = container.makePlanService()
}
#endif

// MARK: - UIApplicationDelegate
extension AppDelegate: UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupLogsForApp()
        setupDebugHelpers()
        
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")
        // Use shared defaults
        let sharedDefaults = UserDefaults(suiteName: AppConstants.AppGroups.main)!
        Storage.setSpecificDefaults(sharedDefaults, largeDataStorage: FileStorage.cached)

        setupCoreIntegration()
        
//        Waiting for https://github.com/getsentry/sentry-cocoa/issues/1892 to be fixed
//        SentryHelper.setupSentry(dsn: ObfuscatedConstants.sentryDsniOS)
        
        AnnouncementButtonViewModel.shared = container.makeAnnouncementButtonViewModel()

        vpnManager.whenReady(queue: DispatchQueue.main) {
            self.navigationService.launched()
        }
        
        container.makeMaintenanceManagerHelper().startMaintenanceManager()
                
        _ = container.makeDynamicBugReportManager() // Loads initial bug report config and sets up a timer to refresh it daily.

        container.applicationDidFinishedLoading()
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
        
        return handleAction(action)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let action = url.host else {
            log.error("Invalid URL", category: .app)
            return false
        }
        
        return handleAction(action)
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
        if propertiesManager.featureFlags.pollNotificationAPI, container.makeAuthKeychainHandle().fetch() != nil {
            announcementRefresher.tryRefreshing()
        }

        container.makeAppSessionManager().refreshVpnAuthCertificate(success: { }, failure: { _ in })
        container.makeReview().activated()
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

    func handleAction(_ action: String) -> Bool {
        switch action {
            
        case URLConstants.deepLinkLoginAction:
            DispatchQueue.main.async { [weak self] in
                self?.navigationService.presentWelcome(initialError: nil)                
            }
            
        case URLConstants.deepLinkConnectAction:
            // Extensions requesting a connection should set a connection request first
            navigationService.vpnGateway.quickConnect(trigger: .widget)
            NotificationCenter.default.addObserver(self, selector: #selector(stateDidUpdate), name: VpnGateway.connectionChanged, object: nil)
            navigationService.presentStatusViewController()
            
        case URLConstants.deepLinkDisconnectAction:
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.widget))
            navigationService.vpnGateway.disconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }

        case URLConstants.deepLinkRefresh, URLConstants.deepLinkRefreshAccount:
            guard container.makeAuthKeychainHandle().fetch() != nil else {
                log.debug("User not is logged in, not refreshing user data", category: .app)
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
}

extension AppDelegate {
    private func setupCoreIntegration() {
        ProtonCore_Log.PMLog.callback = { (message, level) in
            switch level {
            case .debug, .info, .trace, .warn:
                log.debug("\(message)", category: .core)
            case .error, .fatal:
                log.error("\(message)", category: .core)
            }
        }

        FeatureFactory.shared.enable(&.unauthSession)
        FeatureFactory.shared.enable(&.observability)
        FeatureFactory.shared.enable(&.externalSignup)
        
        #if DEBUG
        // this flag is for tests — it should never be turned on in release builds
        if ProcessInfo.processInfo.arguments.contains("enforceUnauthSessionStrictVerificationOnBackend") {
            FeatureFactory.shared.enable(&.enforceUnauthSessionStrictVerificationOnBackend)
        }
        #endif
        let apiService = container.makeNetworking().apiService
        apiService.acquireSessionIfNeeded { _ in
            /* the result doesn't require any handling */
        }
        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)
    }
}
