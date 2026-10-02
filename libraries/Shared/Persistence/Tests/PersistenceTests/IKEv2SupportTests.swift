//
//  Created on 28/09/2026 by Max Kupetskyi.
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
import Persistence
import PersistenceTestSupport
import XCTest

/// Infra is retiring IKEv2, and the API adds an IKEv2 entry only to the servers that still accept it. The server list
/// and quick connect both read protocol support from these queries, so no other server may match IKEv2 here.
final class IKEv2SupportTests: TestIsolatedDatabaseTestCase {
    private let wireGuardEntries: PerProtocolEntries = [
        .wireGuard(.udp): .init(ipv4: nil, ports: nil),
        .wireGuard(.tcp): .init(ipv4: nil, ports: nil),
        .wireGuard(.tls): .init(ipv4: nil, ports: nil),
    ]

    private let keeperEntries: PerProtocolEntries = [
        .wireGuard(.udp): .init(ipv4: nil, ports: nil),
        .wireGuard(.tcp): .init(ipv4: nil, ports: nil),
        .wireGuard(.tls): .init(ipv4: nil, ports: nil),
        .ike: .init(ipv4: nil, ports: nil),
    ]

    private func server(id: String, entries: PerProtocolEntries?) -> VPNServer {
        let server = TestData.createMockServer(withID: id)
        let endpoint = ServerEndpoint(
            id: "endpoint\(id)",
            entryIp: "10.0.0.1",
            exitIp: "10.0.0.2",
            domain: "a",
            status: 1,
            label: nil,
            x25519PublicKey: "",
            protocolEntries: entries
        )
        return VPNServer(logical: server.logical, endpoints: [endpoint])
    }

    func testOnlyServersWithAnIKEv2EntryMatchIKEv2() {
        repository.upsert(servers: [
            server(id: "keeper", entries: keeperEntries),
            server(id: "wireGuardOnly", entries: wireGuardEntries),
            server(id: "withoutEntries", entries: nil),
        ])

        let ikev2Servers = repository.getServers(filteredBy: [.supports(protocol: .ikev2)], orderedBy: .nameAscending)
        let wireGuardServers = repository.getServers(
            filteredBy: [.supports(protocol: .wireGuardUDP)],
            orderedBy: .nameAscending
        )

        XCTAssertEqual(ikev2Servers.map(\.logical.id), ["keeper"])
        XCTAssertEqual(wireGuardServers.map(\.logical.id), ["keeper", "wireGuardOnly", "withoutEntries"])
    }

    func testServerWithoutEntriesReportsEveryProtocolExceptIKEv2() throws {
        repository.upsert(servers: [server(id: "withoutEntries", entries: nil)])

        let server = try XCTUnwrap(repository.getServers(filteredBy: [], orderedBy: .none).first)
        let group = try XCTUnwrap(repository.getGroups(filteredBy: [], groupedBy: .serverType).first)

        XCTAssertEqual(server.protocolSupport, [.wireGuardUDP, .wireGuardTCP, .wireGuardTLS])
        XCTAssertEqual(group.protocolSupport, [.wireGuardUDP, .wireGuardTCP, .wireGuardTLS])
    }
}
