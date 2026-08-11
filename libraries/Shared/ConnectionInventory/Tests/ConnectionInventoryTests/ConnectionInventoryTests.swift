//
//  Created on 11/08/2026.
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

@testable import ConnectionInventory
import Dependencies
import Domain
import Foundation
import OrderedCollections
import Persistence
import PersistenceTestSupport
import Testing
import VPNAppCore

@Suite("City state connection spec factory")
struct CityStateConnectionSpecFactoryTests {
    @Test("Builds an exact location from the logical, keeping the canonical city as the subregion")
    func buildsExactLocationFromLogical() {
        let location = CityStateConnectionSpecFactory.serverLocation(for: .make(
            id: "ch-12",
            name: "CH#12",
            city: "Geneva",
            translatedCity: "Genève"
        ))

        #expect(location == .exact(.paid, logicalID: "ch-12", number: 12, subregion: "Geneva", regionCode: "CH"))
    }

    @Test("Labels free servers free so their tier filter applies")
    func labelsFreeServersFree() {
        let location = CityStateConnectionSpecFactory.serverLocation(for: .make(
            id: "ch-free-1",
            name: "CH-FREE#1",
            tier: .free
        ))

        #expect(location == .exact(.free, logicalID: "ch-free-1", number: 1, subregion: nil, regionCode: "CH"))
    }

    @Test("Secure core logicals produce a hop, not an exact server")
    func secureCoreLogicalsProduceHop() {
        let location = CityStateConnectionSpecFactory.serverLocation(for: .make(
            id: "is-ch-1",
            name: "IS-CH#1",
            entryCountryCode: "IS",
            feature: .secureCore
        ))

        #expect(location == .secureCore(.hop(to: "CH", via: "IS")))
    }
}

@Suite("Recents identity")
struct RecentsIdentityTests {
    private static let listMade = ConnectionSpec(
        location: .exact(.paid, logicalID: "ch-12", number: 12, subregion: "Geneva", regionCode: "CH"),
        features: []
    )
    private static let searchMade = ConnectionSpec(
        location: .exact(.paid, logicalID: "ch-12", number: nil, subregion: "Geneva", regionCode: "CH"),
        features: []
    )

    @Test("An exact recent updates in place when the same server connects from another list")
    func sameLogicalUpdatesInPlace() {
        var recents = OrderedSet<RecentConnection>()

        withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 100))
        } operation: {
            recents.updateList(with: Self.listMade)
            recents.pin(recent: recents[0], pinnedDate: Date(timeIntervalSince1970: 150))
            recents.updateList(with: Self.searchMade)
        }

        #expect(recents.count == 1)
        #expect(recents[0].connection == Self.searchMade)
        #expect(recents[0].pinned)
    }

    @Test("Different servers stay distinct recents")
    func differentLogicalsStayDistinct() {
        let otherServer = ConnectionSpec(
            location: .exact(.paid, logicalID: "ch-13", number: 13, subregion: "Geneva", regionCode: "CH"),
            features: []
        )
        var recents = OrderedSet<RecentConnection>()

        withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 100))
        } operation: {
            recents.updateList(with: Self.listMade)
            recents.updateList(with: otherServer)
        }

        #expect(recents.count == 2)
    }

    @Test("Exact locations without logical IDs fall back to whole-location identity")
    func nilLogicalIDComparesWholeLocation() {
        let geneva = ConnectionSpec(
            location: .exact(.paid, logicalID: nil, number: nil, subregion: "Geneva", regionCode: "CH"),
            features: []
        )
        let zurich = ConnectionSpec(
            location: .exact(.paid, logicalID: nil, number: nil, subregion: "Zurich", regionCode: "CH"),
            features: []
        )
        var recents = OrderedSet<RecentConnection>()

        withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 100))
        } operation: {
            recents.updateList(with: geneva)
            recents.updateList(with: zurich)
            recents.updateList(with: geneva)
        }

        #expect(recents.count == 2)
    }
}

@Suite("Repository backed logical provider")
struct LogicalProviderRepositoryTests {
    @Test("Fetches the logical for the requested server ID")
    func fetchesLogicalByID() {
        let logical = withDependencies {
            var repository = ServerRepository.empty()
            repository.server = { filters, _ in
                guard case .logicalID("ch-12") = filters.first else {
                    return nil
                }
                return VPNServer(logical: .make(id: "ch-12"), endpoints: [])
            }
            $0.serverRepository = repository
        } operation: {
            LogicalProvider.repositoryBacked.logical(id: "ch-12")
        }

        #expect(logical?.id == "ch-12")
    }

    @Test("Returns nil for servers missing from the repository")
    func returnsNilForMissingServers() {
        let logical = withDependencies {
            var repository = ServerRepository.empty()
            repository.server = { _, _ in nil }
            $0.serverRepository = repository
        } operation: {
            LogicalProvider.repositoryBacked.logical(id: "gone")
        }

        #expect(logical == nil)
    }
}

private extension Logical {
    static func make(
        id: String = "id",
        name: String = "CH#1",
        tier: VpnTier = .paid,
        entryCountryCode: String = "CH",
        exitCountryCode: String = "CH",
        feature: ServerFeature = [],
        city: String? = nil,
        translatedCity: String? = nil
    ) -> Logical {
        Logical(
            id: id,
            name: name,
            domain: "",
            load: 0,
            entryCountryCode: entryCountryCode,
            exitCountryCode: exitCountryCode,
            tier: tier,
            score: 0,
            status: 1,
            feature: feature,
            city: city,
            state: nil,
            hostCountry: nil,
            translatedCity: translatedCity,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        )
    }
}
