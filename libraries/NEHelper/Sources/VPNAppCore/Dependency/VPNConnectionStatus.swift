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
    public let serverModelId: String
    public let serverExitIP: String
    public let vpnProtocol: VpnProtocol
    public let natType: NATType
    public let safeMode: Bool?
    public let feature: ServerFeature
    public let serverName: String
    public let country: String
    public let city: String?
    public let coordinates: CLLocationCoordinate2D

    public init(connectedDate: Date?, serverModelId: String, serverExitIP: String, vpnProtocol: VpnProtocol, natType: NATType, safeMode: Bool?, feature: ServerFeature, serverName: String, country: String, city: String?, coordinates: CLLocationCoordinate2D) {
        self.connectedDate = connectedDate
        self.serverModelId = serverModelId
        self.serverExitIP = serverExitIP
        self.vpnProtocol = vpnProtocol
        self.natType = natType
        self.safeMode = safeMode
        self.feature = feature
        self.serverName = serverName
        self.country = country
        self.city = city
        self.coordinates = coordinates
    }
}

// MARK: - Mock for previews

extension VPNConnectionActual {
    public static func mock(serverModelId: String = "server-model-id-1",
                            serverExitIP: String = "188.12.32.12",
                            vpnProtocol: VpnProtocol = .wireGuard(.tcp),
                            natType: NATType = .moderateNAT,
                            safeMode: Bool? = nil,
                            feature: ServerFeature = [],
                            serverName: String = "SRV#12",
                            country: String = "CH",
                            city: String? = "Bern"
    ) -> VPNConnectionActual {
        VPNConnectionActual(
            connectedDate: Date(),
            serverModelId: serverModelId,
            serverExitIP: serverExitIP,
            vpnProtocol: vpnProtocol,
            natType: natType,
            safeMode: safeMode,
            feature: feature,
            serverName: serverName,
            country: country,
            city: city,
            coordinates: .mockPoland()
        )
    }
}

// MARK: - Watch for changes

public extension DependencyValues {
    var vpnConnectionStatusPublisher: () -> AsyncStream<VPNConnectionStatus> {
        get { self[VPNConnectionStatusPublisherKey.self] }
        set { self[VPNConnectionStatusPublisherKey.self] = newValue }
    }
}

public enum VPNConnectionStatusPublisherKey: DependencyKey {
    public static let liveValue: () -> AsyncStream<VPNConnectionStatus> = {
#if !targetEnvironment(simulator)
        // Without `#if targetEnvironment(simulator)` SwiftUI previews crash
        assert(false, "Override this dependency!")
#endif
        // Actual implementation sits in the app, to reduce the scope of thing this library depends on
        return AsyncStream<VPNConnectionStatus>.finished
    }
}

extension CLLocationCoordinate2D {
    public static func mockPoland() -> Self {
        .init(latitude: 52.229675, longitude: 21.012231)
    }
}
