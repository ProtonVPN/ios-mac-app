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
import Sharing
import VPNAppCore

/// Resets user-scoped settings to their defaults on logout (and on login, to clear any prior
/// session's state). Replaces the legacy `PropertiesManager.logoutCleanup()`.
public func performLogoutCleanup() {
    @Shared(.hasConnected) var hasConnected
    $hasConnected.withLock { $0 = false }

    @Shared(.discourageSecureCore) var discourageSecureCore
    $discourageSecureCore.withLock { $0 = true }

    @Shared(.reportBugEmail) var reportBugEmail
    $reportBugEmail.withLock { $0 = nil }

    @Shared(.secureCoreToggle) var secureCoreToggle
    $secureCoreToggle.withLock { $0 = false }

    @Shared(.alternativeRouting) var alternativeRouting
    $alternativeRouting.withLock { $0 = true }

    @Shared(.smartProtocol) var smartProtocol
    $smartProtocol.withLock { $0 = ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault }

    @Shared(.killSwitch) var killSwitch
    $killSwitch.withLock { $0 = false }

    @Shared(.userInfo) var userInfo
    $userInfo.withLock { $0 = nil }

    @Shared(.userSettings) var userSettings
    $userSettings.withLock { $0 = nil }
}
