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

/// Also known as `split-tcp`.
public enum VPNAccelerator: String, Codable, ToggleableFeature {
    case off
    case on
}

extension VPNAccelerator: PaidAppFeature {
    public static let featureFlag: KeyPath<FeatureFlags, Bool>? = \.vpnAccelerator

    public static func minTier(featureFlags: FeatureFlags) -> Int {
        return .paidTier
    }
}

extension VPNAccelerator: ModularAppFeature, DefaultableFeature, StorableFeature {
    public static func defaultValue(
        onPlan plan: String,
        userTier: Int,
        featureFlags: FeatureFlags
    ) -> VPNAccelerator {
        .on
    }

    public static let storageKey: String = "VpnAcceleratorEnabled"
    public static let notificationName: Notification.Name? = Notification.Name("ch.protonvpn.feature.vpnaccelerator.changed")

    public func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        switch self {
        case .off:
            // This feature can only be turned off by paying users post-free rescope
            if userTier < 1 {
                return .failure(.requiresUpgrade)
            }
            return .success
        case .on:
            return .success
        }
    }

    public static let legacyConversion: ((Bool) -> Self)? = { $0 ? .on : .off }
}
