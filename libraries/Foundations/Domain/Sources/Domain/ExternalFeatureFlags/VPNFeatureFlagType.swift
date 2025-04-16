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
public enum VPNFeatureFlagType: String, FeatureFlagTypeProtocol {
    /// Enable or disable Sentry integration. If disabled, SentryHelper.default instance
    /// will be nil, thus calls to it will do nothing.
    case sentry = "Sentry"

    /// Defines if we should exclude full sentry event metadata. Should be disabled
    /// (and can be deleted completely) only after INFSUP-682 is done.
    case sentryExcludeMetadata = "SentryExcludeMetadata"

    /// Don't default to IKEv2 during VPN configuration when no VPN provider is available
    case noDefaultToIke = "AppleVPNNoDefaultToIKE"

    /// Remove connection delay
    case removeConnectionDelay = "RemoveConnectionDelay"

    /// Async VPNManager
    case asyncVPNManager = "AsyncVPNManager"

    /// Plutonium flag for macOS
    case plutoniumMacOS = "Plutonium"

    /// Whether we include the "If-Modified-Since" header for v1/logicals to reduce load
    case timestampedLogicals = "TimestampedLogicals"

    /// Allow Sandbox purchases on TestFlight builds.
    case allowSandboxPurchases = "AllowSandboxPurchases"
}

/// These features are guarded by an additional condition, such as reliance on another flag or an OS version check.
private enum PrivateFeatureFlag: String, FeatureFlagTypeProtocol {
    /// Redesign flag for iOS
    case redesigniOS = "IOSRedesignedUI"

    /// KillSwitch for iOS Redesign UI.
    case redesigniOSKillSwitch = "IOSRedesignedUIKillSwitch"

    /// Use ConnectionFeature reducer from ConnectionPackage
    case useConnectionFeature = "UseConnectionFeature"

    /// KillSwitch for ConnectionFeature reducer usage.
    case useConnectionFeatureKillSwitch = "UseConnectionFeatureKillSwitch"
}

extension FeatureFlagsRepository {
    @available(tvOS, unavailable)
    @available(macOS, unavailable)

    public static let isRedesigniOSEnabled: Bool = {
        if !isFlagEnabled(.redesigniOSKillSwitch) || isFlagEnabled(.redesigniOS) {
            return true
        }
        return false
    }()

    public static let isConnectionFeatureEnabled: Bool = {
        #if os(iOS)
        guard isRedesigniOSEnabled else {
            // ConnectionFeature requires redesign to function since the feature currently lives as a child of the
            // HomeFeature. In addition, parts of the legacy UI (Connection Status, old Map) are not hooked up to
            // the new connection layer.
            return false
        }
        return !isFlagEnabled(.useConnectionFeatureKillSwitch) || isFlagEnabled(.useConnectionFeature)
        #else
        return false
        #endif
    }()

    private static func isFlagEnabled(_ flag: PrivateFeatureFlag) -> Bool {
        FeatureFlagsRepository.shared.isEnabled(flag)
    }
}
