//
//  Created on 2023-06-14.
//
//  Copyright (c) 2023 Proton AG
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

import CoreLocation
import Domain
import Foundation

public struct VPNConnectionActual: Equatable, Codable {
    public let connectedDate: Date?
    public let vpnProtocol: VpnProtocol
    public let natType: NATType
    public let server: Server

    public init(
        connectedDate: Date?,
        vpnProtocol: VpnProtocol,
        natType: NATType,
        server: Server
    ) {
        self.connectedDate = connectedDate
        self.vpnProtocol = vpnProtocol
        self.natType = natType
        self.server = server
    }
}

// MARK: - Mock for previews

#if DEBUG || targetEnvironment(simulator)
    public extension CLLocationCoordinate2D {
        static func mockPoland() -> Self {
            .init(latitude: 52.229675, longitude: 21.012231)
        }
    }

    public extension VPNConnectionActual {
        static func mock(
            connectedDate: Date = Date(),
            serverModelId: String = "server-model-id-1",
            serverExitIP: String = "188.12.32.12",
            vpnProtocol: VpnProtocol = .wireGuard(.tcp),
            natType: NATType = .moderateNAT,
            feature: ServerFeature = [],
            serverName: String = "SRV#12",
            country: String = "CH",
            entryCountry: String? = nil,
            city: String? = "Bern",
            coordinates: CLLocationCoordinate2D = .init(latitude: 46.948076, longitude: 7.459652)
        ) -> VPNConnectionActual {
            VPNConnectionActual(
                connectedDate: connectedDate,
                vpnProtocol: vpnProtocol,
                natType: natType,
                server: Server.mock(
                    serverModelId: serverModelId,
                    serverExitIP: serverExitIP,
                    feature: feature,
                    serverName: serverName,
                    country: country,
                    entryCountry: entryCountry,
                    city: city,
                    coordinates: coordinates
                )
            )
        }
    }

    public extension Server {
        static func mock(
            serverModelId: String = "server-model-id-1",
            serverExitIP: String = "188.12.32.12",
            feature _: ServerFeature = [],
            serverName: String = "SRV#12",
            country: String = "CH",
            entryCountry: String? = nil,
            city: String? = "Bern",
            coordinates: CLLocationCoordinate2D = .init(latitude: 46.948076, longitude: 7.459652)
        ) -> Server {
            Server(
                logical: Logical(
                    id: serverModelId,
                    name: serverName,
                    domain: "",
                    load: 50,
                    entryCountryCode: entryCountry ?? country,
                    exitCountryCode: country,
                    tier: .paid,
                    score: 1,
                    status: 1,
                    feature: .zero,
                    city: city,
                    state: nil,
                    hostCountry: nil,
                    translatedCity: city,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude,
                    gatewayName: nil
                ),
                endpoint: ServerEndpoint(
                    id: "server-endpoint-id-1",
                    entryIp: nil,
                    exitIp: serverExitIP,
                    domain: "",
                    status: 1,
                    label: nil,
                    x25519PublicKey: nil,
                    protocolEntries: nil
                )
            )
        }
    }
#endif
