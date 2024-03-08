//
//  Created on 18/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

/// Controls whether traffic destined for local networks will be excluded from the tunnel
public enum ExcludeLocalNetworks: String, Codable, ToggleableFeature {
    /// LAN Traffic is routed through the tunnel: 'Allow LAN connections' is off in the UI
    case off
    /// LAN Traffic is 'allowed' to bypass tunnel: 'Allow LAN connections' is on in the UI.
    case on

    public func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        switch self {
        case .off:
            return .success
        case .on:
            if featureFlags.showNewFreePlan && userTier.isFreeTier {
                return .failure(.requiresUpgrade)
            }
            return .success
        }
    }
}

extension ExcludeLocalNetworks: ProvidableFeature {

    public static let legacyConversion: ((Bool) -> Self)? = { $0 ? .on : .off }

    public static func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        guard #available(iOS 14.2, *) else {
            return .failure(.featureDisabled)
        }
        if featureFlags.showNewFreePlan && userTier.isFreeTier {
            return .failure(.requiresUpgrade)
        }
        return .success
    }

    public static func defaultValue(
        onPlan plan: String,
        userTier: Int,
        featureFlags: FeatureFlags
    ) -> ExcludeLocalNetworks {
        if featureFlags.showNewFreePlan && userTier.isFreeTier {
            return .off
        }
        return .on
    }

    public static var storageKey: String { "excludeLocalNetworks" }

    public static let notificationName: Notification.Name? = Notification.Name("ch.protonvpn.feature.excludelocalnetworks.changed")
}
