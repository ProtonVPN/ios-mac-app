//
//  Created on 10/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Ergonomics
import Foundation

public extension NetShieldType {
    var lowestTier: Int {
        switch self {
        case .off:
            .freeTier
        default:
            .paidTier
        }
    }

    func isUserTierTooLow(_ userTier: Int) -> Bool {
        userTier < lowestTier
    }

    /// Only applies to a feature flag that we have for Level-3 for now.
    var isDisabled: Bool {
        switch self {
        case .level3:
            !VPNFeatureFlagType.isNetShieldLevelThreeEnabled.enabled
        case .off, .level1, .level2:
            false
        }
    }
}

extension NetShieldType: ModularAppFeature {
    public func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if !featureFlags.netShield {
            return .failure(.featureDisabled)
        }

        if isUserTierTooLow(userTier) {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}

extension NetShieldType: PaidAppFeature {
    public static func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if !featureFlags.netShield {
            return .failure(.featureDisabled)
        }

        if level1.isUserTierTooLow(userTier) {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}
