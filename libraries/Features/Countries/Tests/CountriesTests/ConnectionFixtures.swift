//
//  Created on 10/08/2026 by Max Kupetskyi.
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

import Connection
import Domain
import DomainTestSupport
import Foundation

extension Logical {
    static func stub(
        id: String,
        exitCountryCode: String,
        entryCountryCode: String? = nil,
        city: String? = nil,
        state: String? = nil,
        gatewayName: String? = nil,
        isUnderMaintenance: Bool = false
    ) -> Logical {
        Logical(
            id: id,
            name: id,
            domain: "\(id).protonvpn.net",
            load: 20,
            entryCountryCode: entryCountryCode ?? exitCountryCode,
            exitCountryCode: exitCountryCode,
            tier: .paid,
            score: 1,
            status: isUnderMaintenance ? 0 : 1,
            feature: entryCountryCode == nil ? .zero : .secureCore,
            city: city,
            state: state,
            hostCountry: nil,
            translatedCity: city,
            latitude: 0,
            longitude: 0,
            gatewayName: gatewayName
        )
    }
}

extension ServerInfo {
    static func stub(logical: Logical) -> ServerInfo {
        ServerInfo(logical: logical, protocolSupport: .all)
    }
}

extension ServerGroupInfo {
    static func stub(kind: Kind, isUnderMaintenance: Bool = false, serverCount: Int = 3) -> ServerGroupInfo {
        ServerGroupInfo(
            kind: kind,
            featureIntersection: .zero,
            featureUnion: .zero,
            minTier: .free,
            maxTier: .paid,
            serverCount: serverCount,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: isUnderMaintenance,
            protocolSupport: .all
        )
    }
}

extension ConnectionState {
    static func connected(to logical: Logical) -> ConnectionState {
        .connected(
            .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: [logical.id], killSwitch: false),
            .init(
                currentPeer: Server(logical: logical, endpoint: .mock),
                connectionDate: .now,
                protocolConnectionData: .ike
            )
        )
    }

    static func connecting(to location: ConnectionSpec.Location) -> ConnectionState {
        .connecting(
            .unresolved(ConnectionPreparationIntent(
                spec: ConnectionSpec(location: location, features: []),
                acceptableProtocols: .ikev2
            )),
            tunnelActive: false
        )
    }
}
