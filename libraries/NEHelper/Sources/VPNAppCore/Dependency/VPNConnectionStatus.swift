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

import ConcurrencyExtras
import Dependencies
import NetShield
import CoreLocation
import ComposableArchitecture

import Domain
import Ergonomics

// This struct is still WIP
public enum VPNConnectionStatus: Equatable {
    case disconnected
    case connected(ConnectionSpec, VPNConnectionActual?)
    case connecting(ConnectionSpec, VPNConnectionActual?)
    case loadingConnectionInfo(ConnectionSpec, VPNConnectionActual?)
    case disconnecting(ConnectionSpec, VPNConnectionActual?)

    public var actual: VPNConnectionActual? {
        switch self {
        case .disconnected:
            return nil
        case .connected(_, let vpnConnectionActual),
                .connecting(_, let vpnConnectionActual),
                .loadingConnectionInfo(_, let vpnConnectionActual),
                .disconnecting(_, let vpnConnectionActual):
            return vpnConnectionActual
        }
    }

    public var spec: ConnectionSpec? {
        switch self {
        case .disconnected:
            return nil
        case .connected(let spec, _),
                .connecting(let spec, _),
                .loadingConnectionInfo(let spec, _),
                .disconnecting(let spec, _):
            return spec
        }
    }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<VPNConnectionStatus>> {
    static var vpnConnectionStatus: Self {
        PersistenceKeyDefault(.inMemory("vpnConnectionStatus"), .disconnected)
    }
}

public struct VPNConnectionActual: Equatable {
    public let connectedDate: Date?
    public let vpnProtocol: VpnProtocol
    public let natType: NATType
    public let safeMode: Bool?
    public let server: Server

    public init(
        connectedDate: Date?,
        vpnProtocol: VpnProtocol,
        natType: NATType,
        safeMode: Bool?,
        server: Server
    ) {
        self.connectedDate = connectedDate
        self.vpnProtocol = vpnProtocol
        self.natType = natType
        self.safeMode = safeMode
        self.server = server
    }
}

// MARK: - Watch for changes

public extension DependencyValues {
    var vpnConnectionStatusPublisher: () -> AsyncStream<VPNConnectionStatus> {
        get { self[VPNConnectionStatusPublisherKey.self] }
        set { self[VPNConnectionStatusPublisherKey.self] = newValue }
    }
}

public enum VPNConnectionStatusPublisherKey: TestDependencyKey {
    public static let testValue: () -> AsyncStream<VPNConnectionStatus> = { .finished }
}

extension CLLocationCoordinate2D {
    public static func mockPoland() -> Self {
        .init(latitude: 52.229675, longitude: 21.012231)
    }
}

// MARK: - Mock for previews

#if DEBUG
extension VPNConnectionActual {
    public static func mock(
        connectedDate: Date = Date(),
        serverModelId: String = "server-model-id-1",
        serverExitIP: String = "188.12.32.12",
        vpnProtocol: VpnProtocol = .wireGuard(.tcp),
        natType: NATType = .moderateNAT,
        safeMode: Bool? = nil,
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
            safeMode: safeMode,
            server: Server(
                logical: Logical(
                    id: serverModelId,
                    name: serverName,
                    domain: "",
                    load: 50,
                    entryCountryCode: entryCountry ?? country,
                    exitCountryCode: country,
                    tier: 2,
                    score: 1,
                    status: 1,
                    feature: .zero,
                    city: city,
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
        )
    }
}
#endif
