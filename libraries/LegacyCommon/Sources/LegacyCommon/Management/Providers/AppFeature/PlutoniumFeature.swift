//
//  Created on 2025-05-19 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

import Domain

public enum Plutonium {
    public static let defaultValue: Plutonium = .off

    case off
    case on
}

extension Plutonium: Codable {}

extension Plutonium: PaidAppFeature {
    public static func minTier(featureFlags: FeatureFlags) -> Int {
        return .paidTier
    }
}

extension Plutonium: ToggleableFeature {}

extension Plutonium: ModularAppFeature {
    public func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
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
}

extension Plutonium: DefaultableFeature {
    public static func defaultValue(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> Plutonium {
        return .defaultValue
    }
}

extension Plutonium: StorableFeature {
    public static let storageKey: String = "PlutoniumEnabled"

    public static let event: Domain.AppEvent? = .plutonium
}
