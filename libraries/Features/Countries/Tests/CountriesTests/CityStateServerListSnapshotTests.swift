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

#if os(iOS)
    import ComposableArchitecture
    @testable import Countries_iOS
    @testable import CountriesShared
    import Domain
    import Persistence
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
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
            var state = CityStateListFeature.State(countryCode: "PL")
            state.sectionTitle = "Cities (\(servers.count))"
            state.listState = .loaded(listType)
            let store: StoreOf<CityStateListFeature> = .init(initialState: state, reducer: EmptyReducer.init)

            let view = CityStateListView(store: store)
                .backgroundStyle(Color(.background, .weak))
                .colorScheme(.dark)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13ProMax)), named: type.rawValue, testName: "LongList")
        }

        @Test("Long list of servers")
        func longServerList() {
            var state = ServersListFeature.State(countryCode: "PL", listType: .city("Warsaw"))
            state.list = .loaded(MockServerInfo.manyServers)
            let store: StoreOf<ServersListFeature> = .init(initialState: state, reducer: EmptyReducer.init)

            let view = ServersListView(store: store)
                .backgroundStyle(Color(.background, .weak))
                .colorScheme(.dark)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13ProMax)), named: "PL")
        }
    }

    extension CityStateServerListSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }

    private enum MockServerGroup {
        static func withKind(
            _ kind: ServerGroupInfo.Kind,
            features: ServerFeature,
            minTier: Int = .paidTier,
            maxTier: Int = .paidTier,
            supportsSmartRouting: Bool = true
        ) -> ServerGroupInfo {
            .init(
                kind: kind,
                featureIntersection: features,
                featureUnion: features,
                minTier: minTier,
                maxTier: maxTier,
                serverCount: 3,
                cityCount: 1,
                latitude: 0,
                longitude: 0,
                supportsSmartRouting: supportsSmartRouting,
                isUnderMaintenance: false,
                protocolSupport: [.wireGuardTCP, .wireGuardUDP, .wireGuardTLS]
            )
        }

        static var manyCities: [ServerGroupInfo] {
            [
                ("Freeville", [.streaming], Int.freeTier),
                ("Warsaw", ServerFeature.p2p, Int.paidTier),
                ("Suwałki", [.p2p, .tor], Int.paidTier),
                ("Pcim", [], Int.paidTier),
                ("Stara wieś", [.streaming], Int.paidTier),
                ("Koniec Świata", [.tor, .streaming], Int.paidTier),
                ("Potworów", .p2p, Int.paidTier),
                ("Lenie Wielkie", [], Int.paidTier),
                ("Bardzo długa, zmyślona nazwa miejscowości", [.p2p, .tor, .streaming], Int.paidTier),
                ("Chrząszczyszewoszyce", .p2p, Int.paidTier),
            ].map {
                MockServerGroup.withKind(
                    .city(name: $0.0, code: "PL"),
                    features: $0.1,
                    minTier: $0.2,
                    maxTier: $0.2,
                    supportsSmartRouting: !$0.1.isEmpty
                )
            }
        }
    }

    private enum MockServerInfo {
        static var manyServers: [ServerInfo] {
            let servers: [(name: String, load: Int, status: Int, features: ServerFeature, tier: Int)] =
                [
                    ("PL-FREE#01", 0, 1, [.streaming], .freeTier),
                    ("PL#02", 0, 1, [.p2p], .paidTier),
                    ("PL#03", 1, 1, [.tor], .paidTier),
                    ("PL#10", 10, 1, [.streaming], .paidTier),
                    ("PL#20", 20, 1, [.p2p, .tor], .paidTier),
                    ("PL#40", 40, 1, [.p2p, .streaming], .paidTier),
                    ("PL#60", 60, 1, [.tor, .streaming], .paidTier),
                    ("PL#80", 80, 1, [.p2p, .tor, .streaming], .paidTier),
                    ("PL#99", 99, 1, [], .paidTier),
                    ("PL#MAINT#100", 100, 0, [.p2p], .paidTier),
                ]
            return servers
                .map(Domain.Logical.mock)
                .map { ServerInfo(logical: $0, protocolSupport: .all) }
        }
    }

    extension Domain.Logical {
        static func mock(name: String, load: Int, status: Int, features: ServerFeature, tier: Int) -> Self {
            .init(
                id: UUID().uuidString,
                name: name,
                domain: "",
                load: load,
                entryCountryCode: "",
                exitCountryCode: "",
                tier: tier,
                score: 0,
                status: status,
                feature: features,
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
#endif
