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

/// What a profile looks like based on the servers it can reach right now.
///
/// These values come from the current server list. They do NOT decide whether the user is allowed
/// to use profiles — that is a paid feature checked by `ProfileAuthorizer.canUseProfiles`. This type
/// only answers: what is the cheapest server this profile can reach, and are all of its servers down?
public struct ProfileServerAvailability: Equatable, Sendable {
    /// The lowest tier among the servers this profile can reach right now.
    ///
    /// This is a server tier (for example, the cheapest server in a country), not the plan needed to
    /// use profiles. A "fastest"/"random" profile with no country is `.free`, because there is
    /// always a free server to connect to — it does NOT mean the profile itself is free to use. To
    /// decide access, combine this with `ProfileAuthorizer`.
    public let lowestServerTier: VpnTier

    /// True when every server this profile can reach is under maintenance.
    public let isUnderMaintenance: Bool

    /// Creates a profile's server availability.
    public init(lowestServerTier: VpnTier, isUnderMaintenance: Bool) {
        self.lowestServerTier = lowestServerTier
        self.isUnderMaintenance = isUnderMaintenance
    }
}

public extension ServerRepository {
    /// Works out the current ``ProfileServerAvailability`` for a profile from the live server list.
    func serverAvailability(for profile: Profile) -> ProfileServerAvailability {
        serverAvailability(for: profile.serverOffering, serverType: profile.serverType)
    }

    /// Works out the current ``ProfileServerAvailability`` for a server offering and server type.
    func serverAvailability(
        for offering: ServerOffering,
        serverType: ServerType
    ) -> ProfileServerAvailability {
        switch offering {
        case let .custom(wrapper):
            let fallback = wrapper._server
            guard let currentServer = getFirstServer(
                filteredBy: [.logicalID(fallback.id)],
                orderedBy: .fastest
            ) else {
                return ProfileServerAvailability(
                    lowestServerTier: fallback.tier,
                    isUnderMaintenance: fallback.status == 0
                )
            }
            return ProfileServerAvailability(
                lowestServerTier: currentServer.logical.tier,
                isUnderMaintenance: currentServer.logical.isUnderMaintenance
            )

        case let .fastest(countryCode), let .random(countryCode):
            guard let countryCode else {
                // A "fastest"/"random" profile with no country can always reach a free server, so the
                // lowest server tier is free. Note: this does not tell "fastest" (a paid default
                // profile) apart from "random" (a free one) — that split lives in `Profile.accessTier`
                // and `ProfileAuthorizer`, not here.
                return ProfileServerAvailability(
                    lowestServerTier: .free,
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
                // No matching servers: no tier can reach it, and we show it as under maintenance.
                return ProfileServerAvailability(
                    lowestServerTier: VpnTier(rawValue: .max),
                    isUnderMaintenance: true
                )
            }
            return ProfileServerAvailability(
                lowestServerTier: group.minTier,
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
