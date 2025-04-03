//
//  Created on 2024-12-16.
//
//  Copyright (c) 2024 Proton AG
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

import Foundation
import IssueReporting

public enum DomainConstants {
    public enum AppGroups {
        public static let main = "group.ch.protonmail.vpn"
    }

    public static let maxDeviceCount: Int = 10

    public enum WatershedEvent {
        public static let telemetrySettingDefaultValue = Date(timeIntervalSince1970: 1_690_840_800) // 1st August 2023, 00:00:00
    }

    public enum Maintenance {
        public static let defaultMaintenanceCheckTime: Int = 10 // Minutes
    }
        
    public enum LogFiles {
        // Name of the log file from WireGuard NE.
        public static let wireGuard = "WireGuard.log"
    }
}

public extension UserDefaults {
    static let domainUserDefaults: UserDefaults = {
        .init(suiteName: DomainConstants.AppGroups.main)!
    }()
}

public enum VPNLink: String, CaseIterable {
    case signUp = "https://account.protonvpn.com/signup"
    case accountDashboard = "https://account.protonvpn.com/dashboard"
    case learnMore = "https://protonvpn.com/support/secure-core-vpn"
    case killSwitchSupport = "https://protonvpn.com/support/what-is-kill-switch"
    case netshieldSupport = "https://protonvpn.com/support/netshield"
    case support = "https://protonvpn.com/support"
    case supportForm = "https://protonvpn.com/support-form"
    case supportCommonIssues = "https://protonvpn.com/support/common-macos-issues-protonvpn"
    case resetPassword = "https://account.protonvpn.com/reset-password"
    case forgotUsername = "https://account.protonvpn.com/forgot-username"
    case termsAndConditions = "https://protonvpn.com/terms-and-conditions"
    case privacyPolicy = "https://protonvpn.com/privacy-policy"
    case unsecureWiFi = "https://protonvpn.com/blog/public-wifi-safety"
    case alternativeRouting = "http://protonmail.com/blog/anti-censorship-alternative-routing"
    case vpnAccelerator = "https://protonvpn.com/support/how-to-use-vpn-accelerator"
    case assignVPNConnections = "https://protonvpn.com/support/assign-vpn-connection"
    case moderateNAT = "https://protonvpn.com/support/moderate-nat"
    case safeMode = "https://protonvpn.com/support/non-standard-ports"
    case loginProblems = "https://protonvpn.com/support/login-problems"
    case systemExtensionsInstallationHelp = "https://protonvpn.com/support/how-to-change-vpn-protocols"

    case learnMoreSmartRouting = "https://protonvpn.com/support/smart-routing"
    case learnMoreStreaming = "https://protonvpn.com/support/streaming-guide"
    case learnMoreP2p = "https://protonvpn.com/support/bittorrent-vpn"
    case learnMoreTor = "https://protonvpn.com/support/tor-vpn"
    case learnMoreLoads = "https://protonvpn.com/support/server-load-percentages-and-colors-explained"
    case learnMoreTelemetry = "https://protonvpn.com/support/share-usage-statistics"

    case ping = "https://account.protonvpn.com/api/tests/ping"
    case protocolDeprecations = "https://protonvpn.com/blog/remove-vpn-protocols-apple"
    case ikev2Deprecation = "https://protonvpn.com/support/discontinuing-ikev2-openvpn-macos-ios"

    case dedicatedIps = "https://protonvpn.com/support/dedicated-ips"
    case t2ChipKnowledgeBase = "https://protonvpn.com/support/macos-t2-chip-kill-switch"

    public var url: URL {
        // All URLs get tested in URLTests
        guard let url = URL(string: urlString) else {
            reportIssue("URL \(rawValue) is not a valid URL string!")
            return URL(string: "https://proton.me")!
        }

        return url
    }

    private static let platformRef: String = {
        #if os(iOS)
            return "ios"
        #elseif os(macOS)
            return "mac"
        #elseif os(watchOS)
            return "watchos"
        #elseif os(tvOS)
            return "tvos"
        #elseif os(visionOS)
            return "visionos"
        #else
            return "appleos"
        #endif
    }()

    public var urlString: String {
        "\(rawValue)?ref=\(Self.platformRef)"
    }
}
