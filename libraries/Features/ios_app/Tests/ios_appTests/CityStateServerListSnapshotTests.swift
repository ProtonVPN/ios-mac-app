//
//  Created on 07/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import Domain
@testable import ios_app
import Persistence
import SnapshotTesting
import SwiftUI
import System
import Testing

import Theme

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct CityStateServerListSnapshotTests {
    enum ListType: String {
        case cities
        case states
    }

    @Test("Long list of cities", arguments: [ListType.cities, .states])
    func longList(_ type: ListType) {
        let servers = MockServerGroup.manyCities + MockServerGroup.manyCities
        let listType: CityStateListType = switch type {
        case .cities:
            .cities(servers)
        case .states:
            .states(servers)
        }
        let state = CityStateListFeature.State(countryCode: "PL", sectionTitle: "Cities (\(servers.count)", listState: .loaded(listType))
        let store: StoreOf<CityStateListFeature> = .init(initialState: state, reducer: EmptyReducer.init)

        let view = CityStateListView(store: store)
            .backgroundStyle(Color(.background, .weak))
            .colorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13ProMax)), named: type.rawValue, testName: "LongList")
    }

    @Test("Long list of servers")
    func longServerList() {
        let state = ServersListFeature.State(countryCode: "PL", listType: .city("Warsaw"), list: .loaded(MockServerInfo.manyServers))
        let store: StoreOf<ServersListFeature> = .init(initialState: state, reducer: EmptyReducer.init)

        let view = ServersListView(store: store)
            .backgroundStyle(Color(.background, .weak))
            .colorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13ProMax)), named: "PL")
    }
}

extension CityStateServerListSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/ios_app/Tests/ios_appTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}

private enum MockServerGroup {
    static func withKind(_ kind: ServerGroupInfo.Kind, features: ServerFeature, supportsSmartRouting: Bool = true) -> ServerGroupInfo {
        .init(kind: kind, featureIntersection: features, featureUnion: features, minTier: .paidTier, maxTier: .paidTier, serverCount: 3, cityCount: 1, latitude: 0, longitude: 0, supportsSmartRouting: supportsSmartRouting, isUnderMaintenance: false, protocolSupport: [.wireGuardTCP, .wireGuardUDP, .wireGuardTLS])
    }

    static var manyCities: [ServerGroupInfo] {
        [
            ("Warsaw", ServerFeature.p2p),
            ("Suwałki", [.p2p, .tor]),
            ("Pcim", []),
            ("Stara wieś", .p2p),
            ("Koniec Świata", .tor),
            ("Potworów", .p2p),
            ("Lenie Wielkie", []),
            ("Bardzo długa, zmyślona nazwa miejscowości", [.p2p, .tor]),
            ("Chrząszczyszewoszyce", .p2p),
        ].map {
            MockServerGroup.withKind(.city(name: $0.0, code: "PL"), features: $0.1, supportsSmartRouting: !$0.1.isEmpty)
        }
    }
}

private enum MockServerInfo {
    static var manyServers: [ServerInfo] {
        let servers: [(name: String, load: Int, status: Int)] =
            [
                ("PL#01", 0, 0),
                ("PL#02", 0, 1),
                ("PL#1", 1, 1),
                ("PL#10", 10, 1),
                ("PL#20", 20, 1),
                ("PL#40", 40, 1),
                ("PL#60", 60, 1),
                ("PL#80", 80, 1),
                ("PL#99", 99, 1),
                ("PL#100", 100, 1),
            ]
        return servers
            .map(Domain.Logical.mock)
            .map { ServerInfo(logical: $0, protocolSupport: .all) }
    }
}

extension Domain.Logical {
    static func mock(name: String, load: Int, status: Int) -> Self {
        .init(
            id: UUID().uuidString,
            name: name,
            domain: "",
            load: load,
            entryCountryCode: "",
            exitCountryCode: "",
            tier: 0,
            score: 0,
            status: status,
            feature: [.p2p, .tor, .streaming],
            city: nil,
            state: nil,
            hostCountry: nil,
            translatedCity: nil,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        )
    }
}
