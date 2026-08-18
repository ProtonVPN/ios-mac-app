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
            replaceServers: { _, _ in 0 },
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
            replaceServers: { _, _ in 0 },
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
            replaceServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in .recommendedCountries + .someCountries },
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
            featureUnion: [.streaming],
            minTier: VpnTier(rawValue: 0),
            maxTier: VpnTier(rawValue: 0),
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
            tier: .free,
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

    static func server(name: String, exitCountryCode: String, tier: Int, load: Int, feature: ServerFeature = [], city: String? = nil, state: String? = nil) -> Self {
        .init(
            id: name,
            name: name,
            domain: "\(name).protonvpn.net",
            load: load,
            entryCountryCode: exitCountryCode,
            exitCountryCode: exitCountryCode,
            tier: VpnTier(rawValue: tier),
            score: 0,
            status: 1,
            feature: feature,
            city: city,
            state: state,
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
            replaceServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .country(code: "US"),
                    featureIntersection: .zero,
                    featureUnion: [.p2p, .streaming],
                    minTier: VpnTier(rawValue: 0),
                    maxTier: VpnTier(rawValue: 2),
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

    static func mockWithUSStates() -> Self {
        let freeServers = [
            ServerInfo(logical: .server(name: "US-FREE#1", exitCountryCode: "US", tier: 0, load: 45), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-FREE#2", exitCountryCode: "US", tier: 0, load: 67), protocolSupport: .all),
            ServerInfo(logical: .server(name: "US-FREE#3", exitCountryCode: "US", tier: 0, load: 89), protocolSupport: .all),
        ]

        let plusServers = [
            ServerInfo(
                logical: .server(name: "US-NY#1", exitCountryCode: "US", tier: 2, load: 23, feature: [.p2p], city: "New York", state: "New York"),
                protocolSupport: .all
            ),
            ServerInfo(
                logical: .server(name: "US-NY#2", exitCountryCode: "US", tier: 2, load: 45, feature: [.p2p], city: "New York", state: "New York"),
                protocolSupport: .all
            ),
            ServerInfo(
                logical: .server(name: "US-LA#1", exitCountryCode: "US", tier: 2, load: 34, feature: [.p2p, .streaming], city: "Los Angeles", state: "California"),
                protocolSupport: .all
            ),
            ServerInfo(
                logical: .server(name: "US-LA#2", exitCountryCode: "US", tier: 2, load: 56, feature: [.p2p, .streaming], city: "Los Angeles", state: "California"),
                protocolSupport: .all
            ),
            ServerInfo(
                logical: .server(name: "US-TX#1", exitCountryCode: "US", tier: 2, load: 12, feature: [.p2p], city: "Dallas", state: "Texas"),
                protocolSupport: .all
            ),
        ]

        return .init(
            serverCount: { freeServers.count + plusServers.count },
            countryCount: { 1 },
            upsertServers: { _ in },
            deleteServers: { _, _ in 0 },
            replaceServers: { _, _ in 0 },
            upsertLoads: { _ in },
            groups: { _, _, _ in [
                .init(
                    kind: .state(name: "New York", code: "US"),
                    featureIntersection: .zero,
                    featureUnion: [.p2p, .streaming],
                    minTier: VpnTier(rawValue: 0),
                    maxTier: VpnTier(rawValue: 2),
                    serverCount: 2,
                    cityCount: 1,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
                .init(
                    kind: .state(name: "California", code: "US"),
                    featureIntersection: .zero,
                    featureUnion: [.p2p, .streaming],
                    minTier: VpnTier(rawValue: 0),
                    maxTier: VpnTier(rawValue: 2),
                    serverCount: 2,
                    cityCount: 1,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: false,
                    protocolSupport: .all
                ),
                .init(
                    kind: .state(name: "Texas", code: "US"),
                    featureIntersection: .zero,
                    featureUnion: [.p2p, .streaming],
                    minTier: VpnTier(rawValue: 0),
                    maxTier: VpnTier(rawValue: 2),
                    serverCount: 1,
                    cityCount: 1,
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
}
