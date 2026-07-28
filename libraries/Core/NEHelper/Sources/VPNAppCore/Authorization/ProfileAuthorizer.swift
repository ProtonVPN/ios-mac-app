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

import Dependencies
import DependenciesMacros
import Domain
import Foundation

/// Authorizes access to profiles using the current VPN account tier.
@DependencyClient
public struct ProfileAuthorizer {
    /// Determines whether the current account can use profiles.
    public var shouldAllowProfiles: () -> Bool = { false }

    /// Determines whether the current account can use a profile requiring a tier.
    public var shouldAllowProfile: (_ profileTier: VpnTier) -> Bool = { _ in false }
}

public extension ProfileAuthorizer {
    /// Whether the current account can use profiles.
    var canUseProfiles: Bool {
        shouldAllowProfiles()
    }

    /// Returns whether the current account can use a profile requiring `tier`.
    func canUseProfile(ofTier tier: VpnTier) -> Bool {
        shouldAllowProfile(tier)
    }
}

extension ProfileAuthorizer: DependencyKey {
    public static var liveValue: ProfileAuthorizer {
        ProfileAuthorizer(
            shouldAllowProfiles: {
                @Dependency(\.credentialsProvider) var credentials
                return credentials.tier.isPaid
            },
            shouldAllowProfile: { profileTier in
                @Dependency(\.credentialsProvider) var credentials
                let userTier = credentials.tier
                return userTier.isPaid && userTier >= profileTier
            }
        )
    }

    public static var testValue: ProfileAuthorizer {
        ProfileAuthorizer(
            shouldAllowProfiles: { true },
            shouldAllowProfile: { _ in true }
        )
    }

    public static var previewValue: ProfileAuthorizer {
        testValue
    }
}

public extension DependencyValues {
    /// Authorizes profile access using the current VPN account tier.
    var profileAuthorizer: ProfileAuthorizer {
        get { self[ProfileAuthorizer.self] }
        set { self[ProfileAuthorizer.self] = newValue }
    }
}
