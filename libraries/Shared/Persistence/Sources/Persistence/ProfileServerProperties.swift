//
//  Created on 10/07/2026 by Max Kupetskyi.
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

import Domain

/// Server-derived properties used to display and authorize a profile.
public struct ProfileServerProperties: Equatable, Sendable {
    /// The lowest account tier that can resolve the profile.
    public let requiredTier: Int

    /// Whether every server matching the profile is under maintenance.
    public let isUnderMaintenance: Bool

    /// Creates profile server properties.
    public init(requiredTier: Int, isUnderMaintenance: Bool) {
        self.requiredTier = requiredTier
        self.isUnderMaintenance = isUnderMaintenance
    }
}

public extension ServerRepository {
    /// Resolves current server properties for a profile.
    func serverProperties(for profile: Profile) -> ProfileServerProperties {
        serverProperties(for: profile.serverOffering, serverType: profile.serverType)
    }

    /// Resolves current server properties for a server offering and server type.
    func serverProperties(
        for offering: ServerOffering,
        serverType: ServerType
    ) -> ProfileServerProperties {
        switch offering {
        case let .custom(wrapper):
            let fallback = wrapper._server
            guard let currentServer = getFirstServer(
                filteredBy: [.logicalID(fallback.id)],
                orderedBy: .fastest
            ) else {
                return ProfileServerProperties(
                    requiredTier: fallback.tier,
                    isUnderMaintenance: fallback.status == 0
                )
            }
            return ProfileServerProperties(
                requiredTier: currentServer.logical.tier,
                isUnderMaintenance: currentServer.logical.isUnderMaintenance
            )

        case let .fastest(countryCode), let .random(countryCode):
            guard let countryCode else {
                return ProfileServerProperties(
                    requiredTier: .freeTier,
                    isUnderMaintenance: false
                )
            }
            guard let group = getGroups(
                filteredBy: [
                    .features(serverType.profileServerFeatureFilter),
                    .kind(.country(code: countryCode)),
                ],
                groupedBy: .serverType
            ).first else {
                return ProfileServerProperties(
                    requiredTier: .max,
                    isUnderMaintenance: true
                )
            }
            return ProfileServerProperties(
                requiredTier: group.minTier,
                isUnderMaintenance: group.isUnderMaintenance
            )
        }
    }
}

private extension ServerType {
    var profileServerFeatureFilter: VPNServerFilter.ServerFeatureFilter {
        switch self {
        case .standard:
            .standard
        case .secureCore:
            .secureCore
        case .p2p:
            .standard(with: .p2p)
        case .tor:
            .standard(with: .tor)
        case .unspecified:
            .standard
        }
    }
}
