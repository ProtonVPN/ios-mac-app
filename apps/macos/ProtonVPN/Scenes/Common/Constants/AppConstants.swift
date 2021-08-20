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

class AppConstants {
    
    struct Windows {
        static let loginWidth: CGFloat = 340
        static let loginHeight: CGFloat = 600
        static let sidebarWidth = loginWidth
        static let minimumSidebarHeight: CGFloat = 600
    }
    
    struct UserDefaults {
        static let launchedBefore = "LaunchedBefore"
        static let rememberLogin = "RememberLogin"
        static let rememberLoginAfterUpdate = "RememberLoginAfterUpdate"
        static let startOnBoot = "StartOnBoot"
        static let startMinimized = "StartMinimized"
        static let systemNotifications = "SystemNotifications"
        static let earlyAccess = "EarlyAccess"
        static let unprotectedNetworkNotifications = "UnprotectedNetwork"
        static let dontAskAboutSwift5 = "DontAskAboutSwift5"
        static let mapWidth = "MapWidth"
        static let welcomed = "Welcomed"
        static let trialWelcomed = "TrialWelcomed"
        static let warnedTrialExpiring = "WarnedTrialExpiring"
        static let warnedTrialExpired = "WarnedTrialExpired"
    }
    
    struct FilePaths {
        static let sandbox = ("~/Library/Containers/ch.protonvpn.mac/Data/Library/Preferences/ch.protonvpn.mac.plist" as NSString).expandingTildeInPath
        static let starterSandbox = ("~/Library/Containers/ch.protonvpn.ProtonVPNStarter/" as NSString).expandingTildeInPath
        static let userDefaults = ("~/Library/Preferences/ch.protonvpn.mac.plist" as NSString).expandingTildeInPath
    }
    
    struct Filenames {
        static let openVpnLogFilename = "OpenVPN.log"
    }
    
    struct Time {
        static let maintenanceMessageTimeThreshold: Double = 3600 * 12 // 12 hours
        
        // Servers list refresh
        static let fullServerRefresh: TimeInterval = 3600 * 3 // 3 hours
        static let serverLoadsRefresh: TimeInterval = 60 * 15 // 15 minutes
        
        // Account
        static let userAccountRefresh: TimeInterval = 60 * 3 // 3 minutes
        
        // Status bar blinking speed
        static let statusIconBlink: TimeInterval = 0.6 // seconds
    }
}
