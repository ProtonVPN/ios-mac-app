//
//  Created on 19/04/2024.
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
import enum Domain.VPNFeatureFlagType

public extension ProtonCoreFeatureFlags.FeatureFlag {
    static var sentry: Self {
        VPNFeatureFlagType.sentry.featureFlag
    }
    static var sentryExcludeMetadata: Self {
        VPNFeatureFlagType.sentryExcludeMetadata.featureFlag
    }
    static var certificateRefreshForceRenew: Self {
        VPNFeatureFlagType.certificateRefreshForceRenew.featureFlag
    }
    static var oneClickPayment: Self {
        VPNFeatureFlagType.oneClickPayment.featureFlag
    }
    static var noDefaultToIke: Self {
        VPNFeatureFlagType.noDefaultToIke.featureFlag
    }
    static var removeConnectionDelay: Self {
        VPNFeatureFlagType.removeConnectionDelay.featureFlag
    }
    static var asyncVPNManager: Self {
        VPNFeatureFlagType.asyncVPNManager.featureFlag
    }
}

public extension VPNFeatureFlagType {
    var featureFlag: ProtonCoreFeatureFlags.FeatureFlag {
        .init(name: rawValue, enabled: true, variant: nil)
    }
}
