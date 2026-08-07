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

    public static func serverLocation(for server: ServerInfo, subregion: String) -> ConnectionSpec.Location {
        let entryCountryCode: String? = if case let .secureCore(code) = server.logical.kind { code } else { nil }

        return serverLocation(
            tier: .paid,
            logicalID: server.logical.id,
            number: server.logical.serverNameComponents.sequence,
            subregion: subregion,
            exitCountryCode: server.logical.exitCountryCode,
            entryCountryCode: entryCountryCode
        )
    }

    /// Builds the location for a single server the user picked out of a list.
    /// Pass the entry country code when the server is a Secure Core, `nil` otherwise.
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
