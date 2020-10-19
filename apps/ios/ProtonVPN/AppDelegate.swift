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

import Sentry
import UIKit
import vpncore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let container = DependencyContainer()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = container.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var storeKitManager: StoreKitManager = container.makeStoreKitManager()
    private lazy var servicePlanDataService: ServicePlanDataServiceImplementation = ServicePlanDataServiceImplementation.shared
    
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")
        // Use shared defaults
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: "group.ch.protonmail.vpn")!)
        
        Subscription.specialCoupons = ObfuscatedConstants.specialCoupons
        
        #if RELEASE // to avoid issues with bitcode uploads not being reliable during development
        PMLog.setupSentry(dsn: ObfuscatedConstants.sentryDsn)
        #endif
        
        _ = self.container.makeAuthApiService() // Prepare auth service for 401 response on the first request
        
        // get available iap
        propertiesManager.currentSubscription = nil // ensure the upgrade button isn't present until the app receives confirmation of user's plan
        
        servicePlanDataService.paymentsService = container.makePaymentsApiService() // FUTUREFIX: should inject
        storeKitManager.updateAvailableProductsList()
        _ = storeKitManager.readyToPurchaseProduct() //initial response is always true due to lazy load
    
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
            PMLog.printToConsole("Invalid URL")
            return false
        }
        
        return handleAction(action)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        container.makePropertiesManager().lastTimeForeground = Date()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        let appStateManager = container.makeAppStateManager()
        // If the app was on a closed state, we'll have to wait for the configuration to be established
        appStateManager.onVpnStateChanged = { state in
            appStateManager.onVpnStateChanged = nil
            self.checkStuckConnection(state)
        }
        
        // Otherwise just  check directly  the connection
        let state = container.makeVpnManager().state
        self.checkStuckConnection(state)
        
        // Refresh API announcements
        if propertiesManager.featureFlags.isAnnouncementOn {
            self.container.makeAnnouncementRefresher().refresh()
        }
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        container.makeMaintenanceManager().observeCurrentServerState(every: 0, repeats: false, completion: { maintenance in
            completionHandler( maintenance ? .newData : .noData)
        }, failure: { _ in
            completionHandler(.failed)
        })
    }
}

fileprivate extension AppDelegate {
    
    // MARK: - Private

    func handleAction(_ action: String) -> Bool {
        switch action {
            
        case URLConstants.deepLinkLoginAction:
            DispatchQueue.main.async { [weak self] in
                self?.navigationService.presentLogin(dismissible: false)
            }
            
        case URLConstants.deepLinkConnectAction:
            // Extensions requesting a connection should set a connection request first
            navigationService.vpnGateway?.quickConnect()
            NotificationCenter.default.addObserver(self, selector: #selector(stateDidUpdate), name: VpnGateway.connectionChanged, object: nil)
            
        case URLConstants.deepLinkDisconnectAction:
            navigationService.vpnGateway?.disconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }
        default:
            PMLog.printToConsole("Invalid url action: \(action)")
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
            //wait
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
        // Refresh API announcements
        if propertiesManager.featureFlags.isAnnouncementOn {
            self.container.makeAnnouncementRefresher().refresh()
        }
        
        // Check servers in maintenance
        guard propertiesManager.featureFlags.isServerRefresh else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalNever)
            return
        }
        let time = TimeInterval(propertiesManager.maintenanceServerRefreshIntereval * 60)
        UIApplication.shared.setMinimumBackgroundFetchInterval(time)
    }
    
}
