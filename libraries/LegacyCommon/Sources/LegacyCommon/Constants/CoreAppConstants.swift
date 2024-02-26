//
//  AppConstants.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings

public class CoreAppConstants {
        
    public struct VpnTiers {
        public static let free = 0
        public static let basic = 1
        public static let plus = 2
        public static let visionary = 3
        
        public static let allCases = [free, basic, plus, visionary]
    }
    
    public struct ProtonMailLinks {
        public static let about = "https://protonmail.com/about"
    }
    
    public struct ProtonVpnLinks {
        public static let signUp = "https://account.protonvpn.com/signup"
        public static let accountDashboard = "https://account.protonvpn.com/dashboard"
        public static let learnMore = "https://protonvpn.com/support/secure-core-vpn"
        public static let killSwitchSupport = "https://protonvpn.com/support/what-is-kill-switch"
        public static let netshieldSupport = "https://protonvpn.com/support/netshield"
        public static let support = "https://protonvpn.com/support"
        public static let supportForm = "https://protonvpn.com/support-form"
        public static let supportCommonIssues = "https://protonvpn.com/support/common-macos-issues-protonvpn"
        public static let resetPassword = "https://account.protonvpn.com/reset-password"
        public static let forgotUsername = "https://account.protonvpn.com/forgot-username"
        public static let termsAndConditions = "https://protonvpn.com/terms-and-conditions"
        public static let privacyPolicy = "https://protonvpn.com/privacy-policy"
        public static let appstoreIosUrl = "http://itunes.apple.com/app/id1437005085"
        public static let unsecureWiFiUrl = "https://protonvpn.com/blog/public-wifi-safety/"
        public static let alternativeRouting = "http://protonmail.com/blog/anti-censorship-alternative-routing"
        public static let vpnAccelerator = "https://protonvpn.com/support/how-to-use-vpn-accelerator/"
        public static let assignVPNConnections = "https://protonvpn.com/support/assign-vpn-connection"
        public static let moderateNAT = "https://protonvpn.com/support/moderate-nat"
        public static let safeMode = "https://protonvpn.com/support/non-standard-ports"
        public static let loginProblems = "https://protonvpn.com/support/login-problems"
        public static let systemExtensionsInstallationHelp = "https://protonvpn.com/support/how-to-change-vpn-protocols/"

        public static let learnMoreSmartRouting = "https://protonvpn.com/support/smart-routing"
        public static let learnMoreStreaming = "https://protonvpn.com/support/streaming-guide/"
        public static let learnMoreP2p = "https://protonvpn.com/support/bittorrent-vpn/"
        public static let learnMoreTor = "https://protonvpn.com/support/tor-vpn/"
        public static let learnMoreLoads = "https://protonvpn.com/support/server-load-percentages-and-colors-explained/"
        public static let learnMoreTelemetry = "https://protonvpn.com/support/share-usage-statistics"

        public static let ping = "https://account.protonvpn.com/api/tests/ping"
    }
    
    public struct AttributionLinks {
        public static let fontAwesome = "https://fontawesome.com/"
        public static let fontAwesomeLicense = "https://creativecommons.org/licenses/by/4.0/"
    }
    
    public static func serverTierName(forTier tier: Int) -> String {
        switch tier {
        case 0:
            return Localizable.freeServers
        case 2:
            return Localizable.plusServers
        default:
            return Localizable.testServers
        }
    }
    
    public struct UpdateTime {
        public static let quickUpdateTime: TimeInterval = 3.0
        public static let quickReconnectTime: TimeInterval = 0.5
        
        // Pull announcements from API
        public static let announcementRefreshTime: TimeInterval = 3 * 60 * 60 // 3 h

        // P2P (need to move to LocalAgent for this)
        public static let p2pBlockedRefreshTime: TimeInterval = 90 // 90 seconds
    }

    public struct WatershedEvent {
        public static let freeRescopeReleaseDate = Date(timeIntervalSince1970: 1_694_044_799) // 6th September 2023, 23:59:59
        public static let telemetrySettingDefaultValue = Date(timeIntervalSince1970: 1_690_840_800) // 1st August 2023, 00:00:00
    }

    public struct Maintenance {
        public static let defaultMaintenanceCheckTime: Int = 10 // Minutes
    }
        
    // Pause between reconnection with another protocol
    static let protocolChangeDelay: Int = 1 // seconds

    public struct LogFiles {

        // Name of the log file from OpenVPN NE. Can't change this as it is set inside the TunnelKit pod.
        public static var openVpn = "debug.log"

        // Name of the log file from WireGuard NE.
        public static var wireGuard = "WireGuard.log"
    }
}
