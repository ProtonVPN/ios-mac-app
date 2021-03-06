//
//  AppConstants.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public class CoreAppConstants {
    
    public static let appKeychain = "ProtonVPN"
    
    public struct VpnTiers {
        public static let free = 0
        public static let basic = 1
        public static let visionary = 2
        public static let max = 3
        
        public static let allCases = [free, basic, visionary, max]
    }
    
    public struct ProtonMailLinks {
        public static let about = "https://protonmail.com/about"
    }
    
    public struct ProtonVpnLinks {
        public static let signUp = "https://account.protonvpn.com/signup"
        public static let accountDashboard = "https://account.protonvpn.com/dashboard"
        public static let upgrade = "https://account.protonvpn.com/login"
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
        public static let batteryOpenVpn = "https://protonvpn.com/support/openvpn-battery-usage/"
        public static let alternativeRouting = "http://protonmail.com/blog/anti-censorship-alternative-routing"
    }
    
    public struct AttributionLinks {
        public static let fontAwesome = "https://fontawesome.com/"
        public static let fontAwesomeLicense = "https://creativecommons.org/licenses/by/4.0/"
    }
    
    public static func serverTierName(forTier tier: Int) -> String {
        switch tier {
        case 0:
            return LocalizedString.freeServers
        case 1:
            return LocalizedString.basicServers
        case 2:
            return LocalizedString.plusServers
        default:
            return LocalizedString.testServers
        }
    }
    
    public struct UpdateTime {
        public static let quickUpdateTime: TimeInterval = 3.0
        public static let quickReconnectTime: TimeInterval = 0.5
        
        // Pull announcements from API
        public static let announcementRefreshTime: TimeInterval = 12 * 60 * 60 // 12 h
    }
    
    public struct Maintenance {
        public static let defaultMaintenanceCheckTime: Int = 10 // Minutes
    }

    public struct SmartProtocols {
        public static let openVpnStaticKey = ("6acef03f62675b4b1bbd03e53b187727423cea742242106cb2916a8a4c829756" +
                                            "3d22c7e5cef430b1103c6f66eb1fc5b375a672f158e2e2e936c3faa48b035a6d" +
                                            "e17beaac23b5f03b10b868d53d03521d8ba115059da777a60cbfd7b2c9c57472" +
                                            "78a15b8f6e68a3ef7fd583ec9f398c8bd4735dab40cbd1e3c62a822e97489186" +
                                            "c30a0b48c7c38ea32ceb056d3fa5a710e10ccc7a0ddb363b08c3d2777a3395e1" +
                                            "0c0b6080f56309192ab5aacd4b45f55da61fc77af39bd81a19218a79762c3386" +
                                            "2df55785075f37d8c71dc8a42097ee43344739a0dd48d03025b0450cf1fb5e8c" +
                                            "aeb893d9a96d1f15519bb3c4dcb40ee316672ea16c012664f8a9f11255518deb")
        public static let defaultOpenVpnUdpPorts = [443, 1194, 4569, 5060, 80]
        public static let defaultOpenVpnTcpPorts = [443, 3389, 8080, 8443]
    }
}
