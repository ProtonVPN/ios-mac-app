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

@Suite("Recents server display")
struct RecentsServerDisplayTests {
    private static let spec = ConnectionSpec(
        location: .exact(.paid, logicalID: "ch-12", number: 12, subregion: "Geneva", regionCode: "CH"),
        features: []
    )

    @Test("Connecting captures the display fields alongside the spec")
    func updateListCapturesDisplay() {
        var recents = OrderedSet<RecentConnection>()

        withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 100))
        } operation: {
            recents.updateList(with: Self.spec, display: RecentConnection.ServerDisplay(city: "Genève", number: 12))
        }

        #expect(recents[0].serverDisplay == RecentConnection.ServerDisplay(city: "Genève", number: 12))
    }

    @Test("A server list update rewrites each recent's display fields")
    func refreshRewritesDisplayFromRepository() {
        var recents = OrderedSet<RecentConnection>()
        withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 100))
        } operation: {
            recents.updateList(with: Self.spec, display: RecentConnection.ServerDisplay(city: "Geneva", number: 12))
            recents.updateList(with: ConnectionSpec(location: .country(code: "CH", order: .fastest), features: []))
        }

        var repository = ServerRepository.empty()
        repository.server = { filters, _ in
            guard case .logicalID("ch-12") = filters.first else { return nil }
            return VPNServer(
                logical: .make(id: "ch-12", name: "CH#14", city: "Geneva", translatedCity: "Genève"),
                endpoints: []
            )
        }

        let refreshed = recents.refreshingServerDisplay(from: repository)

        let exact = refreshed.first { $0.connection == Self.spec }
        #expect(exact?.serverDisplay == RecentConnection.ServerDisplay(city: "Genève", number: 14))
        // The country recent names no single server, so it keeps what it had.
        #expect(
            refreshed.first { $0.connection.location == .country(code: "CH", order: .fastest) }?
                .serverDisplay == nil
        )
    }

    @Test("Pinning keeps the stored copy's display fields")
    func pinningKeepsStoredDisplay() {
        var recents = OrderedSet<RecentConnection>()

        withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 100))
        } operation: {
            recents.updateList(with: Self.spec, display: RecentConnection.ServerDisplay(city: "Genève", number: 12))

            // The row hands back a copy from before the display fields were rewritten.
            var stale = recents[0]
            stale.serverDisplay = nil
            recents.pin(recent: stale, pinnedDate: Date(timeIntervalSince1970: 150))
        }

        #expect(recents.count == 1)
        #expect(recents[0].pinned)
        #expect(recents[0].serverDisplay == RecentConnection.ServerDisplay(city: "Genève", number: 12))
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
