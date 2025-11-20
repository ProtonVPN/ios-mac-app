//
//  Created on 07/08/2025 by Max Kupetskyi.
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

public enum PortForwardingNotifications {
    public static let defaultValue: PortForwardingNotifications = .off

    case off
    case on
}

extension PortForwardingNotifications: Codable {}

extension PortForwardingNotifications: PaidAppFeature {
    public static func minTier(featureFlags _: FeatureFlags) -> Int {
        .paidTier
    }
}

extension PortForwardingNotifications: ToggleableFeature {}

extension PortForwardingNotifications: ModularAppFeature {
    public func canUse(userTier: Int, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
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

extension PortForwardingNotifications: DefaultableFeature {
    public static func defaultValue(userTier _: Int, featureFlags _: FeatureFlags) -> PortForwardingNotifications {
        .defaultValue
    }
}

extension PortForwardingNotifications: StorableFeature {
    public static let storageKey: String = "PortForwardingNotificationsEnabled"

    public static let event: Domain.AppEvent? = .portForwardingNotifications
}
