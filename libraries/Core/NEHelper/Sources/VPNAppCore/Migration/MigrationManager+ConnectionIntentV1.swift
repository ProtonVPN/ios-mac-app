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
    /// V1 -> V2: Expands our `ConnectionSpec.Location` to better represent random locations
    /// V2 -> V3: Expands `tunnelSettings` to specify `IKE` and distinguish between WG backends (ProTUN)
    func checkingServerConnectionIntent() -> Self {
        // Originally, the V1 -> V2 migration was implemented for an earlier version, but this migration never
        // executed properly since it was operating on the "ServerConnectionIntent" key entry, while intents were
        // stored per user, e.g: ServerConnectionIntent<username>.
        checking(.platform(iOS: "7.4.2", macOS: "6.5.2", tvOS: "1.6.1")) { _ in
            @Dependency(\.defaultsProvider) var provider
            migrateUserSpecificEntries(
                withKeyPrefix: "ServerConnectionIntent",
                in: provider.getDefaults()
            ) { key, defaults in
                guard let data = defaults.data(forKey: key) else { return }
                let migratedIntent = try migrateOldServerConnectionIntent(from: data)
                defaults.set(migratedIntent, forKey: key)
            }
        }
    }

    private func migrateOldServerConnectionIntent(from data: Data) throws -> Data {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        do {
            let intentV2 = try decoder.decode(ServerConnectionIntent.V2.self, from: data)
            return try encoder.encode(ServerConnectionIntent(migrating: intentV2))
        } catch {
            log.error(
                "Failed to decode ServerConnectionIntent.V2",
                category: .persistence,
                metadata: ["error": "\(error)"]
            )
        }
        // If the migration fails, try to migrate from the V1 format, for users who have not launched the app
        // since the V1 -> V2 migration was introduced.
        let intentV1 = try decoder.decode(ServerConnectionIntent.V1.self, from: data)
        return try encoder.encode(ServerConnectionIntent(migrating: intentV1))
    }
}

private extension ConnectionSpec.SecureCoreSpec {
    enum V1: Codable {
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
    enum V1: Codable {
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
        let location: Location.V1
        let features: Set<Feature>
        let profileId: String?
    }

    init(migrating v1: V1) {
        self = .init(location: .init(migrating: v1.location), features: v1.features, profileId: v1.profileId)
    }
}

private extension WireGuardSettings {
    /// The original `TunnelSettings` struct before `backend` was introduced. All connections at
    /// this point were WireGuard using the Go backend.
    struct V1: Codable {
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
    struct V1: Codable {
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
    struct V2: Codable {
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
