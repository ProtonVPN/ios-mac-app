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

private extension ServerConnectionIntent {
    struct V1: Codable, Sendable {
        public let spec: ConnectionSpec.V1
        public let server: Server
        public let tunnelSettings: TunnelSettings
        public let features: VPNConnectionFeatures
    }

    init(migrating v1: V1) {
        self = .init(
            spec: .init(migrating: v1.spec),
            server: v1.server,
            tunnelSettings: v1.tunnelSettings,
            features: v1.features
        )
    }
}
