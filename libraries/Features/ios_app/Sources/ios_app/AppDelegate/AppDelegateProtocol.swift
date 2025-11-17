//
//  AppDelegateProtocol.swift
//  ProtonVPN - Created on 2025-11-17.
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

import Foundation
import UIKit

/// Protocol defining the core app delegate functionality to be implemented in the ios_app package.
/// This allows the main app target to remain thin while the ios_app package handles all the setup and logic.
public protocol AppDelegateProtocol {
    /// Called during app delegate initialization. Handles early setup that must happen before any other operations.
    func performEarlySetup()

    /// Called when the application finishes launching.
    func applicationDidFinishLaunching()

    /// Called when the application will enter foreground.
    func applicationWillEnterForeground()

    /// Called when the application did enter background.
    func applicationDidEnterBackground()

    /// Called when the application becomes active.
    func applicationDidBecomeActive()

    /// Handles URL opening requests from external sources.
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool

    /// Handles user activity continuation (e.g., Siri intents).
    func handleContinueUserActivity(_ userActivity: NSUserActivity) -> Bool

    /// Called when the app successfully registers for remote notifications.
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data)

    /// Called when the app fails to register for remote notifications.
    func didFailToRegisterForRemoteNotifications(withError error: Error)
}
