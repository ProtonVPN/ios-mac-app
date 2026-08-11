//
//  Created on 24/04/2026 by Max Kupetskyi.
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

public enum CityStateConnectionSpecFactory {
    public static func makeSpec(
        location: ConnectionSpec.Location,
        features: Set<ConnectionSpec.Feature> = []
    ) -> ConnectionSpec {
        .init(location: location, features: features)
    }

    /// Builds the location for a single server the user picked out of a list.
    ///
    /// Every field comes from the logical itself. `subregion` is the canonical city name, never the
    /// translated one: the server selector matches it against the city column when the logical ID is
    /// missing, and recents compare locations for identity.
    public static func serverLocation(for logical: Logical) -> ConnectionSpec.Location {
        if case let .secureCore(entryCountryCode) = logical.kind {
            return .secureCore(.hop(to: logical.exitCountryCode, via: entryCountryCode))
        }

        return .exact(
            logical.tier.isFree ? .free : .paid,
            logicalID: logical.id,
            number: logical.serverNameComponents.sequence,
            subregion: logical.city,
            regionCode: logical.exitCountryCode
        )
    }

    /// Builds the location for a server selection when only search index data is available.
    /// Prefer ``serverLocation(for:)`` wherever a `Logical` is available.
    public static func serverLocation(
        tier: ConnectionSpec.Server,
        logicalID: String?,
        number: Int?,
        subregion: String?,
        exitCountryCode: String,
        entryCountryCode: String?
    ) -> ConnectionSpec.Location {
        if let entryCountryCode {
            return .secureCore(.hop(to: exitCountryCode, via: entryCountryCode))
        }

        return .exact(
            tier,
            logicalID: logicalID,
            number: number,
            subregion: subregion,
            regionCode: exitCountryCode
        )
    }
}
