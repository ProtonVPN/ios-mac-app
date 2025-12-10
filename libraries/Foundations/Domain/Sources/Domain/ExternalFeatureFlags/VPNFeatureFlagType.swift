//
//  Created on 2024-02-09.
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
import ProtonCoreFeatureFlags

/// Feature flag types used across all VPN app platforms (iOS, macOS, etc.).
/// Used with ProtonCore FeatureFlags package:
/// `FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.sentry)`
///
///
/// This enum has to conform to `FeatureFlagTypeProtocol`.  Ideally we should
/// get rid of depending on ProtonCore in this package. In that case, conformance to
/// `FeatureFlagTypeProtocol` can be moved to the apps themselves leaving
/// only enum here.
///
/// Keep in mind that external feature flags update their values only after app restart.
public enum VPNFeatureFlagType: String, CaseIterable, FeatureFlagTypeProtocol {
    /// Enable or disable Sentry integration. If disabled, SentryHelper.default instance
    /// will be nil, thus calls to it will do nothing.
    case sentry = "Sentry"

    /// If we're using a public key that was associated with a previous session UID, tell the backend that it's okay to
    /// evict the previous session UID and associate the key with the current one.
    case certificateRefreshForceRenew = "CertificateRefreshForceRenew"

    /// Remove connection delay
    case removeConnectionDelay = "RemoveConnectionDelay"

    /// Plutonium flag for macOS
    case plutoniumMacOS = "Plutonium"

    /// CustomDNS flag
    case customDNS = "CustomDNS"

    /// Whether we include the "If-Modified-Since" header for v1/logicals to reduce load
    case timestampedLogicals = "TimestampedLogicals"

    /// Allow Sandbox purchases on TestFlight builds.
    case allowSandboxPurchases = "AllowSandboxPurchases"

    /// Enable web purchases for iOS users
    case iapToWeb = "IapToWeb"

    /// Enable web purchases for iOS users in WebView
    case iapToWebView = "IapToWebView"

    case portForwarding = "DisplayPortForwarding"
}

public extension FeatureFlagsRepository {
    static let enabledFeaturesRequestString: String = {
        let features: [any FeatureFlagTypeProtocol] = VPNFeatureFlagType.allCases + CoreFeatureFlagType.allCases
        return features.compactMap(\.requestName).joined(separator: ", ")
    }()

    static var isConnectionFeatureEnabled: Bool = {
        #if os(iOS)
            return true
        #else
            return false
        #endif
    }()
}

public extension FeatureFlagTypeProtocol {
    var shouldReportInHttpRequests: Bool {
        switch self {
        case let coreFlag as CoreFeatureFlagType:
            switch coreFlag {
            case .paymentsV2:
                true
            default:
                false
            }
        default:
            false
        }
    }

    /// This appears in all HTTP requests under the
    var requestName: String? {
        guard shouldReportInHttpRequests else { return nil }

        switch self {
        case is VPNFeatureFlagType:
            return "VPN.\(rawValue)"
        case is CoreFeatureFlagType:
            return "Core.\(rawValue)"
        default:
            assertionFailure("Unrecognized Feature Flag type \(Self.self)")
            return nil
        }
    }
}
