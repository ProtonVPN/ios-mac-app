//
//  AppConstants.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa
import Domain
import VPNShared

class AppConstants {
    enum Windows {
        static let loginWidth: CGFloat = 340
        static let loginHeight: CGFloat = 600
        static let sidebarWidth = loginWidth
        static let minimumSidebarHeight: CGFloat = 600
    }

    enum UserDefaults {
        static let launchedBefore = "LaunchedBefore"
        static let rememberLogin = "RememberLogin"
        static let rememberLoginAfterUpdate = "RememberLoginAfterUpdate"
        static let startOnBoot = "StartOnBoot"
        static let startMinimized = "StartMinimized"
        static let systemNotifications = "SystemNotifications"
        static let earlyAccess = "EarlyAccess"
        static let unprotectedNetworkNotifications = "UnprotectedNetwork"
        static let mapWidth = "MapWidth"
        static let welcomed = "Welcomed"
        static let trialWelcomed = "TrialWelcomed"
        static let warnedTrialExpiring = "WarnedTrialExpiring"
        static let warnedTrialExpired = "WarnedTrialExpired"
        static let uninstallSysexesOnTerminate = "UninstallSysexesOnTerminate"
    }

    enum FilePaths {
        static let sandbox = ("~/Library/Containers/ch.protonvpn.mac/Data/Library/Preferences/ch.protonvpn.mac.plist" as NSString).expandingTildeInPath
        static let starterSandbox = ("~/Library/Containers/ch.protonvpn.ProtonVPNStarter/" as NSString).expandingTildeInPath
        static let userDefaults = ("~/Library/Preferences/ch.protonvpn.mac.plist" as NSString).expandingTildeInPath
    }

    enum Filenames {
        static let appLogFilename = "ProtonVPN.log"
        static let openVpnLogFilename = "OpenVPN.log"
        static let wireGuardLogFilename = "WireGuard.log"
        static let plutoniumLogFilename = "SplitTunneling.log"
    }

    enum NetworkExtensions {
        static let openVpn = "\(DomainConstants.BundleID.main).OpenVPN-Extension"
        static let wireguard = "\(DomainConstants.BundleID.main).WireGuardiOS-Extension"
    }

    enum Time {
        static let recentlyActiveThreshold: TimeInterval = .minutes(10)

        static let maintenanceMessageTimeThreshold: TimeInterval = .hours(12)

        // Servers list refresh
        static let fullServerRefresh: TimeInterval = .hours(3)
        static let serverLoadsRefresh: TimeInterval = .minutes(15)

        // Account
        static let userAccountRefresh: TimeInterval = .minutes(3)

        // Streaming & Partners
        static let streamingInfoRefresh: TimeInterval = .days(2)
        static let partnersInfoRefresh: TimeInterval = .days(2)

        // Status bar blinking speed
        static let statusIconBlink: TimeInterval = .milliseconds(600)
    }

    enum DeepLinking {
        static let deepLinkScheme = "protonvpn"
        static let deepLinkBaseUrl = "\(deepLinkScheme)://"
    }
}
