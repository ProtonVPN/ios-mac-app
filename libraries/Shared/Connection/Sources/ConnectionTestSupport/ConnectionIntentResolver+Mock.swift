//
//  Created on 18/11/2025 by Chris Janusiewicz.
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

import Connection
import CoreConnection
import Domain
import Foundation

package extension ConnectionIntentResolver {
    static func mock(
        server: Server,
        tunnelSettings: TunnelSettings = TunnelSettings(transport: .udp, ports: [80], features: .mock),
        features: VPNConnectionFeatures = .mock
    ) -> ConnectionIntentResolver {
        ConnectionIntentResolver(
            resolve: { intent throws(ProtocolSelectionError) in
                ServerConnectionIntent(
                    spec: intent.spec,
                    server: server,
                    tunnelSettings: tunnelSettings,
                    features: features
                )
            },
            authorize: { _, _ in
                // always authorizes connections
            }
        )
    }
}
