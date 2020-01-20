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
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")
        // Use shared defaults
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: "group.ch.protonmail.vpn")!)
        
        #if RELEASE // to avoid issues with bitcode uploads not being reliable during development
        PMLog.setupSentry(dsn: ObfuscatedConstants.sentryDsn)
        #endif
        
        _ = self.container.makeAuthApiService() // Prepare auth service for 401 response on the first request
        
        // get available iap
        propertiesManager.currentSubscription = nil // ensure the upgrade button isn't present until the app receives confirmation of user's plan
        
        servicePlanDataService.paymentsService = container.makePaymentsApiService() // FUTUREFIX: should inject
        storeKitManager.updateAvailableProductsList()
        
        navigationService.launched()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        appStateManager.refreshState()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let view = url.host else {
            PMLog.printToConsole("Invalid URL")
            return false
        }
        
        switch view {
        case "login":
            DispatchQueue.main.async { [weak self] in
                self?.navigationService.presentLogin(dismissible: false)
            }
            return true
        default:
            PMLog.printToConsole("Invalid view: \(view)")
            return false
        }
    }
}
