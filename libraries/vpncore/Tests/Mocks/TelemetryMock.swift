//
//  Created on 19/12/2022.
//
//  Copyright (c) 2022 Proton AG
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
@testable import vpncore

extension ConnectionEvent {
    static let connectionMock1 = ConnectionEvent(event: .vpnConnection(123),
                                                 dimensions: .connectionSuccessMock1)
    static let disconnectionMock1 = ConnectionEvent(event: .vpnDisconnection(123),
                                                    dimensions: .disconnectionSuccessMock1)
}

extension ConnectionEventType.Value {
    static let connectionMock1 = ConnectionEventType.Value(timeToConnection: 123)
    static let disconnectionMock1 = ConnectionEventType.Value(sessionLength: 123)
}

extension TelemetryDimensions {
    static let connectionSuccessMock1 = TelemetryDimensions(outcome: .success,
                                                            userTier: .free,
                                                            vpnStatus: .on,
                                                            vpnTrigger: .country,
                                                            networkType: .wifi,
                                                            serverFeatures: .zero,
                                                            vpnCountry: "CHE",
                                                            userCountry: "FRA",
                                                            protocol: .wireGuard(.tls),
                                                            server: "#IT1",
                                                            port: "1234",
                                                            isp: "Play")
    
    static let disconnectionSuccessMock1 = TelemetryDimensions(outcome: .success,
                                                               userTier: .paid,
                                                               vpnStatus: .off,
                                                               vpnTrigger: .server,
                                                               networkType: .mobile,
                                                               serverFeatures: [.p2p, .tor],
                                                               vpnCountry: "POL",
                                                               userCountry: "BEL",
                                                               protocol: .openVpn(.udp),
                                                               server: "#PL1",
                                                               port: "5678",
                                                               isp: "Netia")
}
