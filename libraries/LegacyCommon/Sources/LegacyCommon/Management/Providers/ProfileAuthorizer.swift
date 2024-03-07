//
//  Created on 11/08/2023.
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
import Dependencies

public struct ProfileAuthorizer {
    var shouldAllowProfiles: () -> Bool
    var shouldAllowProfile: (_ profileTier: Int) -> Bool

    public var canUseProfiles: Bool { shouldAllowProfiles() }
    public func canUseProfile(ofTier tier: Int) -> Bool { shouldAllowProfile(tier) }
}

extension ProfileAuthorizer: DependencyKey {
    public static var liveValue: ProfileAuthorizer = {
        @Dependency(\.credentialsProvider) var credentials
        @Dependency(\.featureFlagProvider) var featureFlags

        let shouldAllowProfiles: () -> Bool = { featureFlags[\.showNewFreePlan] ? credentials.tier > CoreAppConstants.VpnTiers.free : true }

        return ProfileAuthorizer(
            shouldAllowProfiles: shouldAllowProfiles,
            shouldAllowProfile: { profileTier in
                guard shouldAllowProfiles() else {
                    return false
                }
                return credentials.tier >= profileTier
            }
        )
    }()
}

extension DependencyValues {
    public var profileAuthorizer: ProfileAuthorizer {
        get { self[ProfileAuthorizer.self] }
        set { self[ProfileAuthorizer.self] = newValue }
    }
}
