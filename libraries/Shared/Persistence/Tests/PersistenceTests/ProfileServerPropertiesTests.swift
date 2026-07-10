//
//  Created on 10/07/2026 by Max Kupetskyi.
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

import Domain
@testable import Persistence
import PersistenceTestSupport
import Testing

struct ProfileServerPropertiesTests {
    @Test
    func resolvesCurrentCustomServerProperties() {
        let fallback = serverModel(id: "server", tier: .freeTier, status: 1)
        var repository = ServerRepository.empty()
        repository.server = { _, _ in
            TestData.createMockServer(
                withID: "server",
                tier: .paidTier,
                status: 0
            )
        }

        let properties = repository.serverProperties(
            for: .custom(ServerWrapper(server: fallback)),
            serverType: .standard
        )

        #expect(properties.requiredTier == .paidTier)
        #expect(properties.isUnderMaintenance)
    }

    @Test
    func fallsBackToWrappedCustomServer() {
        let fallback = serverModel(id: "missing", tier: .internalTier, status: 0)
        let repository = ServerRepository.empty()

        let properties = repository.serverProperties(
            for: .custom(ServerWrapper(server: fallback)),
            serverType: .standard
        )

        #expect(properties.requiredTier == .internalTier)
        #expect(properties.isUnderMaintenance)
    }

    @Test
    func resolvesCountryGroupMinimumTierAndMaintenance() {
        var repository = ServerRepository.empty()
        repository.groups = { _, _, _ in
            [
                ServerGroupInfo(
                    kind: .country(code: "US"),
                    featureIntersection: .zero,
                    featureUnion: .zero,
                    minTier: .paidTier,
                    maxTier: .internalTier,
                    serverCount: 2,
                    cityCount: 1,
                    latitude: 0,
                    longitude: 0,
                    supportsSmartRouting: false,
                    isUnderMaintenance: true,
                    protocolSupport: .wireGuardUDP
                ),
            ]
        }

        let properties = repository.serverProperties(
            for: .fastest("US"),
            serverType: .standard
        )

        #expect(properties.requiredTier == .paidTier)
        #expect(properties.isUnderMaintenance)
    }

    @Test
    func treatsCountrylessProfileAsFreeAndAvailable() {
        let repository = ServerRepository.empty()

        let properties = repository.serverProperties(
            for: .random(nil),
            serverType: .standard
        )

        #expect(properties.requiredTier == .freeTier)
        #expect(!properties.isUnderMaintenance)
    }

    @Test
    func deniesProfileWhenCountryGroupIsMissing() {
        let repository = ServerRepository.empty()

        let properties = repository.serverProperties(
            for: .fastest("US"),
            serverType: .standard
        )

        #expect(properties.requiredTier == .max)
        #expect(properties.isUnderMaintenance)
    }

    private func serverModel(id: String, tier: Int, status: Int) -> ServerModel {
        ServerModel(
            id: id,
            name: id,
            domain: "\(id).example",
            load: 0,
            entryCountryCode: "US",
            exitCountryCode: "US",
            tier: tier,
            feature: .zero,
            city: nil,
            state: nil,
            ips: [],
            score: 0,
            status: status,
            location: ServerLocation(lat: 0, long: 0),
            hostCountry: nil,
            translatedCity: nil,
            gatewayName: nil
        )
    }
}
