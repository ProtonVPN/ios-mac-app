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

import CertificateAuthentication
import Connection
import CoreConnectionTestSupport
import Domain
import DomainTestSupport
import Foundation
import VPNShared

public extension ConnectionFeature.State {
    static let connected: ConnectionFeature.State = {
        let now = Date.now
        let tomorrow = now.addingTimeInterval(.days(1))

        let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        let certificate = VpnCertificate(certificate: "1234", validUntil: tomorrow, refreshTime: tomorrow)

        let intent = ServerConnectionIntent(spec: .defaultFastest, server: .mock, tunnelSettings: .mock, features: .mock)

        return ConnectionFeature.State(
            currentIntent: intent,
            queuedIntent: nil,
            connectionState: .connected(intent, .mock, .now, nil),
            shouldRegisterServerChangeOnConnection: false,
            core: .init(
                tunnelState: .init(
                    neState: .connected,
                    maskedState: .connected(.init(logicalInfo: .init(logicalID: "abc", serverID: "abc"), connectionDate: .now))
                ),
                certAuthState: .loaded(.init(keys: .init(fromLegacyKeys: keys), certificate: certificate, features: .mock)),
                localAgentState: .connected(nil)
            )
        )
    }()
}
