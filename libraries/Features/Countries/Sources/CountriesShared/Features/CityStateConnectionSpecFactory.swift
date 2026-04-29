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
    public static func makeSpec(location: ConnectionSpec.Location) -> ConnectionSpec {
        .init(location: location, features: [])
    }

    static func serverLocation(for server: ServerInfo, subregion: String) -> ConnectionSpec.Location {
        if case .secureCore = server.logical.kind {
            return .secureCore(.hop(
                to: server.logical.exitCountryCode,
                via: server.logical.entryCountryCode
            ))
        }

        return .exact(
            .paid,
            logicalID: server.logical.id,
            number: server.logical.serverNameComponents.sequence,
            subregion: subregion,
            regionCode: server.logical.exitCountryCode
        )
    }
}
