//
//  Created on 19.01.2026 by John Biggs.
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

import Dependencies
import Domain
import Ergonomics
import Foundation

extension MigrationManager {
    func checkingConnectionSpec() -> Self {
        checking(.platform(iOS: "7.0.1", macOS: "6.2.0", tvOS: "1.4.1")) { _ in
            @Dependency(\.defaultsProvider) var provider
            let defaults = provider.getDefaults()
            let key = "ServerConnectionIntent"
            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            if let data = defaults.data(forKey: key),
               let previous = try? decoder.decode(ServerConnectionIntent.V1.self, from: data) {
                let newIntent = ServerConnectionIntent(migrating: previous)
                try defaults.set(encoder.encode(newIntent), forKey: key)
            }
        }
    }

    /// ProTUN: Migrates `ServerConnectionIntent`, replacing WireGuard Go specific `tunnelSettings` with
    /// `protocolConfiguration` which allows the intent to specify a IKE and distinguish between WG backends
    func checkingProtocolConfiguration() -> Self {
        checking(.platform(iOS: "7.5.0", macOS: "6.6.0", tvOS: "1.7.0")) { _ in
            @Dependency(\.defaultsProvider) var provider
            let defaults = provider.getDefaults()
            let key = "ServerConnectionIntent"
            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            if let data = defaults.data(forKey: key),
               let previous = try? decoder.decode(ServerConnectionIntent.V2.self, from: data) {
                let newIntent = ServerConnectionIntent(migrating: previous)
                try defaults.set(encoder.encode(newIntent), forKey: key)
            }
        }
    }
}

private extension ConnectionSpec.SecureCoreSpec {
    enum V1: Codable, Sendable {
        case random
        case fastest
        case fastestHop(to: String)
        case hop(to: String, via: String)
    }

    init(migrating v1: V1) {
        switch v1 {
        case .random:
            self = .any(.random)
        case .fastest:
            self = .any(.fastest)
        case let .fastestHop(to):
            self = .anyHop(to: to, .fastest)
        case let .hop(to, via):
            self = .hop(to: to, via: via)
        }
    }
}

private extension ConnectionSpec.Location {
    enum V1: Codable, Sendable {
        case fastest
        case random
        case country(code: String)
        case city(name: String, code: String)
        case exact(ConnectionSpec.Server, logicalID: String?, number: Int?, subregion: String?, regionCode: String)
        case secureCore(ConnectionSpec.SecureCoreSpec.V1)
        case gateway(name: String)
    }

    init(migrating v1: V1) {
        switch v1 {
        case .fastest:
            self = .any(.fastest)
        case .random:
            self = .any(.random)
        case let .country(code):
            self = .country(code: code, order: .fastest)
        case let .city(name, code):
            self = .city(name: name, code: code, order: .fastest)
        case let .exact(server, logicalID, number, subregion, regionCode):
            self = .exact(server, logicalID: logicalID, number: number, subregion: subregion, regionCode: regionCode)
        case let .secureCore(spec):
            self = .secureCore(.init(migrating: spec))
        case let .gateway(name):
            self = .gateway(name: name)
        }
    }
}

private extension ConnectionSpec {
    struct V1: Codable {
        public let location: Location.V1
        public let features: Set<Feature>
        public let profileId: String?
    }

    init(migrating v1: V1) {
        self = .init(location: .init(migrating: v1.location), features: v1.features, profileId: v1.profileId)
    }
}

private extension WireGuardSettings {
    /// The original `TunnelSettings` struct before `backend` was introduced. All connections at
    /// this point were WireGuard using the Go backend.
    struct V1: Codable, Sendable {
        let transport: WireGuardTransport
        let ports: [Int]
        let features: TunnelFeatures
    }

    init(migrating v1: V1) {
        self = .init(backend: .go, transport: v1.transport, ports: v1.ports, features: v1.features)
    }
}

private extension ServerConnectionIntent {
    /// Pre-random server selection improvements, using old connection spec location definitions.
    struct V1: Codable, Sendable {
        let spec: ConnectionSpec.V1
        let server: Server
        let tunnelSettings: TunnelSettings.V1
        let features: VPNConnectionFeatures
    }

    init(migrating v1: V1) {
        self = .init(
            spec: .init(migrating: v1.spec),
            server: v1.server,
            protocolConfiguration: .wireGuard(.init(migrating: v1.tunnelSettings)),
            features: v1.features
        )
    }

    /// Pre-ProTUN: old `ConnectionSpec` location format with `tunnelSettings` (no `protocolConfiguration`).
    struct V2: Codable, Sendable {
        let spec: ConnectionSpec
        let server: Server
        let tunnelSettings: WireGuardSettings.V1
        let features: VPNConnectionFeatures
    }

    init(migrating v2: V2) {
        self = .init(
            spec: v2.spec,
            server: v2.server,
            protocolConfiguration: .wireGuard(.init(migrating: v2.tunnelSettings)),
            features: v2.features
        )
    }
}
