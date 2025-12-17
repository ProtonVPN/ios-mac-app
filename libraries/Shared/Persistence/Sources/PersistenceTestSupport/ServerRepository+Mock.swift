//
//  Created on 12/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Domain
@testable import Persistence

public extension ServerRepository {
    static func empty() -> Self {
        .init(
            serverCount: { 0 },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [] },
            servers: { _, _ in [] },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func notEmpty() -> Self {
        .init(
            serverCount: { 1 },
            countryCount: { 1 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [] },
            servers: { _, _ in [] },
            server: { _, _ in .mock },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func somePlusRecommendedCountries() -> Self {
        .init(
            serverCount: { 0 },
            countryCount: { 10 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in .recommendedCountries + .someCountries },
            servers: { _, _ in [] },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func emptyWithUpsert() -> Self {
        .init(
            serverCount: { 0 },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [] },
            servers: { _, _ in [] },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }
}

extension VPNServer {
    static var mock: Self {
        .init(logical: .mock, endpoints: [.mock])
    }
}

extension [ServerGroupInfo] {
    static var recommendedCountries: Self {
        ["US", "UK", "CA", "FR", "DE"]
            .map { .country(code: $0) }
    }

    static var someCountries: Self {
        ["PL", "AR", "RO", "LT", "CZ"]
            .map { .country(code: $0) }
    }
}

extension ServerGroupInfo {
    static func country(code: String) -> Self {
        .init(
            kind: .country(code: code),
            featureIntersection: .zero,
            featureUnion: .zero,
            minTier: 0,
            maxTier: 0,
            serverCount: 5,
            cityCount: 0,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )
    }
}

extension ServerEndpoint {
    static var mock: Self {
        .init(
            id: "some id",
            entryIp: "1.2.3.4",
            exitIp: "4.3.2.1",
            domain: "domain",
            status: 1,
            label: nil,
            x25519PublicKey: nil,
            protocolEntries: nil
        )
    }
}

extension Domain.Logical {
    static var mock: Self {
        .init(
            id: "",
            name: "",
            domain: "",
            load: 0,
            entryCountryCode: "",
            exitCountryCode: "",
            tier: 0,
            score: 0,
            status: 0,
            feature: [],
            city: nil,
            state: nil,
            hostCountry: nil,
            translatedCity: nil,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        )
    }

    static func server(name: String, exitCountryCode: String, tier: Int, load: Int, feature: ServerFeature = [], city: String? = nil) -> Self {
        .init(
            id: name,
            name: name,
            domain: "\(name).protonvpn.net",
            load: load,
            entryCountryCode: exitCountryCode,
            exitCountryCode: exitCountryCode,
            tier: tier,
            score: 0,
            status: 1,
            feature: feature,
            city: city,
            hostCountry: nil,
            translatedCity: city,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        )
    }
}

// MARK: - Country-specific mocks for snapshot tests

public extension ServerRepository {
    static func mockWithUSServers() -> Self {
        let freeServers = [
            ServerInfo(logical: .server(name: "US-FREE#1", exitCountryCode: "US", tier: 0, load: 45), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-FREE#2", exitCountryCode: "US", tier: 0, load: 67), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-FREE#3", exitCountryCode: "US", tier: 0, load: 89), protocolSupport: .all),
        ]

        let plusServers = [
            ServerInfo(logical: .server(name: "US-NY#1", exitCountryCode: "US", tier: 2, load: 23, feature: [.p2p], city: "New York"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-NY#2", exitCountryCode: "US", tier: 2, load: 45, feature: [.p2p], city: "New York"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-LA#1", exitCountryCode: "US", tier: 2, load: 34, feature: [.p2p, .streaming], city: "Los Angeles"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-LA#2", exitCountryCode: "US", tier: 2, load: 56, feature: [.p2p, .streaming], city: "Los Angeles"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-TX#1", exitCountryCode: "US", tier: 2, load: 12, feature: [.p2p], city: "Dallas"), protocolSupport: .all),
        ]

        return .init(
            serverCount: { freeServers.count + plusServers.count },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .country(code: "US"),
                    featureIntersection: .zero,
                    featureUnion: [.p2p, .streaming],
                    minTier: 0,
                    maxTier: 2,
                    serverCount: freeServers.count + plusServers.count,
                    cityCount: 3,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
            ] },
            servers: { _, _ in freeServers + plusServers },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func mockWithGBServers() -> Self {
        let plusServers = [
            ServerInfo(logical: .server(name: "UK-LON#1", exitCountryCode: "GB", tier: 2, load: 15, feature: [.ipv6, .p2p, .streaming], city: "London"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "UK-LON#2", exitCountryCode: "GB", tier: 2, load: 28, feature: [.ipv6, .p2p, .streaming], city: "London"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "UK-LON#3", exitCountryCode: "GB", tier: 2, load: 42, feature: [.ipv6, .p2p, .streaming], city: "London"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "UK-MAN#1", exitCountryCode: "GB", tier: 2, load: 33, feature: [.ipv6, .p2p], city: "Manchester"), protocolSupport: .all),
            ServerInfo(logical: .server(name: "UK-MAN#2", exitCountryCode: "GB", tier: 2, load: 51, feature: [.ipv6, .p2p], city: "Manchester"), protocolSupport: .all),
        ]

        return .init(
            serverCount: { plusServers.count },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .country(code: "GB"),
                    featureIntersection: [.ipv6, .p2p],
                    featureUnion: [.ipv6, .p2p, .streaming],
                    minTier: 2,
                    maxTier: 2,
                    serverCount: plusServers.count,
                    cityCount: 2,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
            ] },
            servers: { _, _ in plusServers },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func mockWithCHServers() -> Self {
        let secureCoreServers = [
            ServerInfo(logical: .server(name: "CH-SE#1", exitCountryCode: "CH", tier: 2, load: 18, feature: [.secureCore]), protocolSupport: .all),
            ServerInfo(logical: .server(name: "CH-IS#1", exitCountryCode: "CH", tier: 2, load: 25, feature: [.secureCore]), protocolSupport: .all),
            ServerInfo(logical: .server(name: "CH#1", exitCountryCode: "CH", tier: 2, load: 32, feature: [.secureCore]), protocolSupport: .all),
        ]

        return .init(
            serverCount: { secureCoreServers.count },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .country(code: "CH"),
                    featureIntersection: [.secureCore],
                    featureUnion: [.secureCore],
                    minTier: 2,
                    maxTier: 2,
                    serverCount: secureCoreServers.count,
                    cityCount: 0,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
            ] },
            servers: { _, _ in secureCoreServers },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func mockWithNLServers() -> Self {
        let freeServers = [
            ServerInfo(logical: .server(name: "NL-FREE#1", exitCountryCode: "NL", tier: 0, load: 78), protocolSupport: .all),
            ServerInfo(logical: .server(name: "NL-FREE#2", exitCountryCode: "NL", tier: 0, load: 92), protocolSupport: .all),
        ]

        return .init(
            serverCount: { freeServers.count },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .country(code: "NL"),
                    featureIntersection: .zero,
                    featureUnion: .zero,
                    minTier: 0,
                    maxTier: 0,
                    serverCount: freeServers.count,
                    cityCount: 0,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
            ] },
            servers: { _, _ in freeServers },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }

    static func mockWithSEServers() -> Self {
        let torServers = [
            ServerInfo(logical: .server(name: "SE#1-TOR", exitCountryCode: "SE", tier: 2, load: 21, feature: [.tor, .p2p]), protocolSupport: .all),
            ServerInfo(logical: .server(name: "SE#2-TOR", exitCountryCode: "SE", tier: 2, load: 38, feature: [.tor, .p2p]), protocolSupport: .all),
            ServerInfo(logical: .server(name: "SE#3-TOR", exitCountryCode: "SE", tier: 2, load: 45, feature: [.tor, .p2p]), protocolSupport: .all),
            ServerInfo(logical: .server(name: "SE#4-TOR", exitCountryCode: "SE", tier: 2, load: 52, feature: [.tor, .p2p]), protocolSupport: .all),
        ]

        return .init(
            serverCount: { torServers.count },
            countryCount: { 0 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .country(code: "SE"),
                    featureIntersection: [.tor, .p2p],
                    featureUnion: [.tor, .p2p],
                    minTier: 2,
                    maxTier: 2,
                    serverCount: torServers.count,
                    cityCount: 0,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
            ] },
            servers: { _, _ in torServers },
            server: { _, _ in nil },
            getMetadata: { _ in nil },
            setMetadata: { _, _ in },
            closeConnection: {}
        )
    }
}
