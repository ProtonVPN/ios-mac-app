//
//  Created on 02/07/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain
import Foundation
import LegacyCommon
import ServiceManagement
import Sharing

// macOS-only settings migrated off the legacy `PropertiesManager+Extension` / `AppConstants.UserDefaults`.
// The macOS default sharing store is `UserDefaults.standard`, matching the store
// these keys previously used, so existing values are read transparently.

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    /// Whether the app registers itself as a login item (starts on boot).
    static var startOnBoot: Self {
        Self[.appStorage("StartOnBoot"), default: false]
    }

    /// Whether the app starts minimized to the menu bar.
    static var startMinimized: Self {
        Self[.appStorage("StartMinimized"), default: false]
    }

    /// Whether system notifications are enabled.
    static var systemNotifications: Self {
        Self[.appStorage("SystemNotifications"), default: false]
    }

    /// Whether unprotected-network notifications are enabled.
    static var unprotectedNetworkNotifications: Self {
        Self[.appStorage("UnprotectedNetwork"), default: false]
    }

    /// Whether the system extensions should be uninstalled when the app terminates.
    static var uninstallSysexesOnTerminate: Self {
        Self[.appStorage("UninstallSysexesOnTerminate"), default: false]
    }

    /// Whether the app has launched before (used by the first-launch routine).
    static var launchedBefore: Self {
        Self[.appStorage("LaunchedBefore"), default: false]
    }

    /// Whether the user has completed the system-extension welcome/tour.
    static var welcomed: Self {
        Self[.appStorage("Welcomed"), default: false]
    }
}

extension SharedKey where Self == AppStorageKey<Int>.Default {
    /// The persisted map container width, in points (stored as an integer). Legacy key: `MapWidth`.
    static var mapWidth: Self {
        Self[.appStorage("MapWidth"), default: 0]
    }
}

// MARK: - Start-on-boot login item

/// Sets the start-on-boot preference and registers/unregisters the app as a login item to match.
/// Replaces the legacy `PropertiesManager.startOnBoot` setter side effect.
func setStartOnBoot(_ enabled: Bool) {
    @Shared(.startOnBoot) var startOnBoot
    $startOnBoot.withLock { $0 = enabled }
    setLoginItem(enabled: enabled)
}

/// Re-applies the current start-on-boot preference to the system login-item registration.
/// Replaces the legacy `PropertiesManager.restoreStartOnBootStatus()`.
func restoreStartOnBootStatus() {
    @SharedReader(.startOnBoot) var startOnBoot
    setLoginItem(enabled: startOnBoot)
}

private func setLoginItem(enabled: Bool) {
    do {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        log.error("Failed to \(enabled ? "register" : "unregister") login item: \(error)", category: .app)
    }
}
