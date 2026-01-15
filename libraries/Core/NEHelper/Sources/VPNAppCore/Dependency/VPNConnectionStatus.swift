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

import ComposableArchitecture
import CoreLocation

#if canImport(WidgetKit)
    import WidgetKit
#endif

import Domain
import Ergonomics
import NetShield

import CasePaths
import ConcurrencyExtras
import Dependencies
import Sharing

// This struct is still WIP
@CasePathable
public enum VPNConnectionStatus: Sendable, Equatable, Codable {
    case resolving(ConnectionSpec?, VPNConnectionActual?)
    case disconnected
    case connected(ConnectionSpec, VPNConnectionActual?)
    case connecting(ConnectionSpec, Server?)
    case disconnecting(ConnectionSpec, VPNConnectionActual?)

    public var server: Server? {
        if case let .connecting(_, server) = self {
            return server
        }
        return actual?.server
    }

    public var actual: VPNConnectionActual? {
        switch self {
        case .disconnected:
            nil
        case let .connected(_, vpnConnectionActual),
             let .resolving(_, vpnConnectionActual),
             let .disconnecting(_, vpnConnectionActual):
            vpnConnectionActual
        case .connecting:
            nil
        }
    }

    public var spec: ConnectionSpec? {
        switch self {
        case .disconnected, .resolving(.none, _):
            nil
        case let .connected(spec, _),
             let .connecting(spec, _),
             let .resolving(.some(spec), _),
             let .disconnecting(spec, _):
            spec
        }
    }
}

private let persistentFileUrl: URL = (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DomainConstants.AppGroups.main) ?? .documentsDirectory).appendingPathComponent(
    "shared/vpnConnectionStatus.json"
)

public extension SharedKey where Self == FileStorageKey<VPNConnectionStatus>.Default {
    static var vpnConnectionStatus: Self {
        Self[
            .fileStorage(
                persistentFileUrl,
                decode: { data in
                    try JSONDecoder().decode(VPNConnectionStatus.self, from: data)
                },
                encode: { status in
                    #if canImport(WidgetKit)
                        defer {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    #endif
                    return try JSONEncoder().encode(status)
                }
            ),
            default: .resolving(nil, nil)
        ]
    }
}

public struct VPNConnectionActual: Equatable, Codable {
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

@available(macOS 13, *)
@available(tvOS, unavailable)
public extension DependencyValues {
    var vpnConnectionStatusPublisher: () -> AsyncStream<VPNConnectionStatus> {
        get { self[VPNConnectionStatusPublisherKey.self] }
        set { self[VPNConnectionStatusPublisherKey.self] = newValue }
    }
}

@available(macOS 13, *)
@available(tvOS, unavailable)
public enum VPNConnectionStatusPublisherKey: TestDependencyKey {
    public static let testValue: () -> AsyncStream<VPNConnectionStatus> = { .finished }
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
        }
    }
#endif
