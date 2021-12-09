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

import UIKit
import vpncore
import ProtonCore_Services
import ProtonCore_Log
import ProtonCore_UIFoundations
import Logging
import Foundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let container = DependencyContainer()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var planService: PlanService = container.makePlanService()
    
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        setupLogsForApp()
        
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")
        // Use shared defaults
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: AppConstants.AppGroups.main)!)

        ApiConstants.doh = DoHVPN(apiHost: ObfuscatedConstants.apiHost, verifyHost: ObfuscatedConstants.humanVerificationV3Host)

        setupCoreIntegration()
        
        SentryHelper.setupSentry(dsn: ObfuscatedConstants.sentryDsniOS)
        
        AnnouncementButtonViewModel.shared = container.makeAnnouncementButtonViewModel()

        setupCoreIntegration()
    
        navigationService.launched()
        
        container.makeMaintenanceManagerHelper().startMaintenanceManager()
        NotificationCenter.default.addObserver(self, selector: #selector(featureFlagsChanged), name: PropertiesManager.featureFlagsNotification, object: nil)
                
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        appStateManager.refreshState()
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle Siri intents
        let prefix = "com.protonmail.vpn."
        guard #available(iOS 12.0, *), userActivity.activityType.hasPrefix(prefix) else {
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
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        log.info("applicationDidBecomeActive", category: .os)
        var appStateManager = container.makeAppStateManager()
        // If the app was on a closed state, we'll have to wait for the configuration to be established
        appStateManager.onVpnStateChanged = { state in
            appStateManager.onVpnStateChanged = nil
            self.checkStuckConnection(state)
        }
        
        // Otherwise just  check directly  the connection
        let state = container.makeVpnManager().state
        self.checkStuckConnection(state)
        
        // Refresh API announcements
        let announcementRefresher = self.container.makeAnnouncementRefresher() // This creates refresher that is persisted in DI container
        if propertiesManager.featureFlags.pollNotificationAPI, AuthKeychain.fetch() != nil {
            announcementRefresher.refresh()
        }

        container.makeAppSessionManager().refreshVpnAuthCertificate(success: { }, failure: { _ in })
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        container.makeMaintenanceManager().observeCurrentServerState(every: 0, repeats: false, completion: { maintenance in
            completionHandler( maintenance ? .newData : .noData)
        }, failure: { _ in
            completionHandler(.failed)
        })
    }
    
    private func setupLogsForApp() {
        LoggingSystem.bootstrap {_ in
            return MultiplexLogHandler([
                ConsoleLogHandler(),
                FileLogHandler(self.container.makeLogFileManager().getFileUrl(named: AppConstants.Filenames.appLogFilename))
            ])
        }
    }
}

fileprivate extension AppDelegate {
    
    // MARK: - Private

    func handleAction(_ action: String) -> Bool {
        switch action {
            
        case URLConstants.deepLinkLoginAction:
            DispatchQueue.main.async { [weak self] in
                self?.navigationService.presentWelcome()                
            }
            
        case URLConstants.deepLinkConnectAction:
            // Extensions requesting a connection should set a connection request first
            navigationService.vpnGateway?.quickConnect()
            NotificationCenter.default.addObserver(self, selector: #selector(stateDidUpdate), name: VpnGateway.connectionChanged, object: nil)
            navigationService.presentStatusViewController()
            
        case URLConstants.deepLinkDisconnectAction:
            navigationService.vpnGateway?.disconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }
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
            let state = self.container.makeVpnManager().state
            
            guard case .connecting = state else {
                propertiesManager.lastTimeForeground = nil
                return
            }
            
            let lastTime = propertiesManager.lastTimeForeground
            
            if lastTime == nil || lastTime!.timeIntervalSinceNow > AppConstants.Time.timeForForegroundStuck {
                self.container.makeVpnGateway().quickConnect()
            }
                
            propertiesManager.lastTimeForeground = nil
        }
    }
    
    @objc func featureFlagsChanged() {
        // Check servers in maintenance
        guard propertiesManager.featureFlags.serverRefresh else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalNever)
            return
        }
        let time = TimeInterval(propertiesManager.maintenanceServerRefreshIntereval * 60)
        UIApplication.shared.setMinimumBackgroundFetchInterval(time)
    }
    
}

extension AppDelegate {
    private func setupCoreIntegration() {
        ColorProvider.brand = .vpn

        let trusKitHelper = container.makeTrustKitHelper()
        PMAPIService.trustKit = trusKitHelper?.trustKit
        PMAPIService.noTrustKit = trusKitHelper?.trustKit == nil

        ProtonCore_Log.PMLog.callback = { (message, level) in
            switch level {
            case .debug, .info, .trace, .warn:
                log.debug("[Core] \(message)", category: .app)
            case .error, .fatal:
                log.error("[Core] \(message)", category: .app, source: "Core")
            }
        }
    }
}
