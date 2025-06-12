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

import Domain
import Foundation

/// Also known as `split-tcp`.
public enum VPNAccelerator: String, Codable, ToggleableFeature {
    case off
    case on
}

extension VPNAccelerator: PaidAppFeature {
    public static let featureFlag: KeyPath<FeatureFlags, Bool>? = \.vpnAccelerator

    public static func minTier(featureFlags _: FeatureFlags) -> Int {
        .paidTier
    }
}

extension VPNAccelerator: ModularAppFeature, DefaultableFeature, StorableFeature {
    public static let event: AppEvent? = .vpnAccelerator

    public static func defaultValue(
        onPlan _: String,
        userTier _: Int,
        featureFlags _: FeatureFlags
    ) -> VPNAccelerator {
        .on
    }

    public static let storageKey: String = "VpnAcceleratorEnabled"

    public func canUse(onPlan _: String, userTier: Int, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        switch self {
        case .off:
            // This feature can only be turned off by paying users post-free rescope
            if userTier.isFreeTier {
                return .failure(.requiresUpgrade)
            }
            return .success
        case .on:
            return .success
        }
    }

    public static let legacyConversion: ((Bool) -> Self)? = { $0 ? .on : .off }
}
