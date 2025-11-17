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
import Foundation
import UIKit

// Third-party dependencies
#if DEBUG
    import Atlantis
#endif

import ios_app
import LegacyCommon
import ProtonCoreCryptoVPNPatchedGoImplementation

final class AppDelegate: UIResponder {
    private let appDelegateService: AppDelegateProtocol = AppDelegateService()

    override init() {
        super.init()

        #if DEBUG
            Atlantis.start()
        #endif

        // Inject crypto implementation (binary framework, must be in app target)
        injectDefaultCryptoImplementation()

        appDelegateService.performEarlySetup()
    }
}

// MARK: - UIApplicationDelegate

extension AppDelegate: UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup Siri intents (only available in main app target due to Intent definitions)
        SiriHelper.quickConnectIntent = QuickConnectIntent()
        SiriHelper.disconnectIntent = DisconnectIntent()

        appDelegateService.applicationDidFinishLaunching()
        return true
    }

    func applicationWillEnterForeground(_: UIApplication) {
        appDelegateService.applicationWillEnterForeground()
    }

    func application(_: UIApplication, continue userActivity: NSUserActivity, restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        appDelegateService.handleContinueUserActivity(userActivity)
    }

    func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        appDelegateService.handleOpenURL(url, options: options)
    }

    func applicationDidEnterBackground(_: UIApplication) {
        appDelegateService.applicationDidEnterBackground()
    }

    func applicationDidBecomeActive(_: UIApplication) {
        appDelegateService.applicationDidBecomeActive()
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        appDelegateService.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        appDelegateService.didFailToRegisterForRemoteNotifications(withError: error)
    }
}
