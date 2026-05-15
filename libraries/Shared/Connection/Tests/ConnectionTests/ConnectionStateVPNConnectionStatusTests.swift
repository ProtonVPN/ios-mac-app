//
//  Created on 15/05/2026 by Max Kupetskyi.
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

#if DEBUG
    @testable import Connection
    import Domain
    import Testing
    import VPNAppCore

    struct ConnectionStateVPNConnectionStatusTests {
        @Test
        func unresolvedConnectingStatusDoesNotReusePreviousServer() {
            let previousStatus = VPNConnectionStatus.connected(.defaultFastest, .mock(serverName: "AF#3", country: "AF"))
            let newSpec = ConnectionSpec(location: .country(code: "JP", order: .fastest), features: [])
            let connectionState = ConnectionState.connecting(.unresolved(.init(spec: newSpec, acceptableProtocols: .all)))

            let status = connectionState.vpnConnectionStatus(
                fallbackSpec: .defaultFastest,
                previousStatus: previousStatus
            )

            #expect(status == .connecting(newSpec, nil))
        }
    }
#endif
