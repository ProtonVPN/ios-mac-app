//
//  Created on 24/03/2025 by Chris Janusiewicz.
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
import CoreConnectionTestSupport
import Domain
import DomainTestSupport
import ExtensionManager
import Foundation
import VPNShared

public extension ConnectionFeature.State {
    static let connected: ConnectionFeature.State = {
        let now = Date.now
        let tomorrow = now.addingTimeInterval(.days(1))

        let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        return ConnectionFeature.State(
            connectionState: .connected(
                TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"]),
                .init(currentPeer: .mock, connectionDate: now, protocolConnectionData: .ike)

            ),
            shouldRegisterServerChangeOnConnection: false,
            core: .init(
                tunnelState: .connected(
                    TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"]),
                    DynamicConnectionData(currentPeerId: "peer-id", connectionDate: now, protocolConnectionData: .ike)
                )
            )
        )
    }()
}
