//
//  Created on 14/08/2026 by Max Kupetskyi.
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
import Persistence
import PersistenceTestSupport
import Testing

/// An endpoint the API sends without any address cannot be connected to, so nothing may report it as
/// supporting a protocol.
@Suite("Endpoint protocol support")
struct EndpointProtocolSupportTests {
    private let repository: ServerRepository = withDependencies {
        $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral(filePath: nil))
    } operation: {
        ServerRepositoryKey.liveValue
    }

    private func endpoint(entryIp: String?, protocolEntries: PerProtocolEntries? = nil) -> ServerEndpoint {
        ServerEndpoint(
            id: "endpoint",
            entryIp: entryIp,
            exitIp: "1.2.3.5",
            domain: "a",
            status: 1,
            label: nil,
            x25519PublicKey: "key",
            protocolEntries: protocolEntries
        )
    }

    private func selectFastest() throws -> Server {
        try withDependencies {
            $0.serverRepository = repository
        } operation: {
            try ServerSelector.liveValue.select(.defaultFastest, .paid, .all)
        }
    }

    // MARK: - Domain

    @Test("An endpoint with no address at all supports no protocols")
    func endpointWithoutAddressSupportsNoProtocols() {
        let endpoint = endpoint(entryIp: nil)

        #expect(endpoint.supportedProtocols == .zero)
        #expect(!endpoint.supports(protocolSet: .all))
    }

    @Test("An endpoint with only a default address supports every protocol")
    func endpointWithDefaultAddressSupportsEveryProtocol() {
        #expect(endpoint(entryIp: "1.2.3.4").supportedProtocols == .all)
    }

    @Test("Only the protocols with a per-protocol address count when the default address is absent")
    func endpointWithoutDefaultAddressSupportsOnlyItsOverriddenProtocols() {
        let endpoint = endpoint(
            entryIp: nil,
            protocolEntries: [.wireGuard(.udp): .init(ipv4: "1.1.1.1", ports: nil)]
        )

        #expect(endpoint.supportedProtocols == .wireGuardUDP)
    }

    // MARK: - Persistence

    @Test("An endpoint with no address is not stored as supporting protocols")
    func endpointWithoutAddressIsNotStoredAsSupportingProtocols() throws {
        repository.upsert(servers: [TestData.createMockServer(withID: "no-address", entryIp: nil)])

        let info = try #require(repository.getServers(filteredBy: [], orderedBy: .none).first)
        #expect(info.protocolSupport == .zero)
    }

    // MARK: - Selection

    @Test("A server whose only endpoint has no address is never selected")
    func serverWithoutAddressIsNotSelectable() {
        repository.upsert(servers: [TestData.createMockServer(withID: "no-address", score: 1, entryIp: nil)])

        #expect(throws: ServerSelector.SelectionError.noLogical(.protocolNotSupported(.all))) {
            try selectFastest()
        }
    }

    @Test("A reachable server is selected over a faster one with no address")
    func serverWithAnAddressIsPreferredOverOneWithout() throws {
        let unreachable = TestData.createMockServer(withID: "no-address", score: 1, entryIp: nil)
        let reachable = TestData.createMockServer(withID: "with-address", score: 2)
        repository.upsert(servers: [unreachable, reachable])

        let selected = try selectFastest()

        #expect(selected.logical.id == reachable.id)
        #expect(selected.endpoint.entryIp != nil)
    }
}
