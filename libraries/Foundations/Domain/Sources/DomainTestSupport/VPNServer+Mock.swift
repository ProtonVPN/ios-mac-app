//
//  Created on 06/06/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Domain

extension VPNServer {
    public static let mock = VPNServer(
        logical: Logical(
            id: "oMDUA_xB",
            name: "CH#1", domain: "node-ch-1.mock.protonvpn.net",
            load: 50,
            entryCountryCode: "EU",
            exitCountryCode: "EU",
            tier: 2,
            score: 2.0,
            status: 1,
            feature: [.p2p, .streaming],
            city: "Geneva",
            hostCountry: nil,
            translatedCity: "Geneva",
            latitude: 50.8,
            longitude: 4.3,
            gatewayName: nil
        ),
        endpoints: [
            ServerEndpoint(
                id: "SHdjRDAd",
                entryIp: "1.2.3.4",
                exitIp: "5.6.7.8",
                domain: "node-ch-1.mock.protonvpn.net",
                status: 1,
                label: "2",
                x25519PublicKey: "8NeySGpn",
                protocolEntries: nil
            )
        ]
    )
}
