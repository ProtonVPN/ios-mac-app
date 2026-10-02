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
import Foundation
import Testing

/// Infra is retiring IKEv2, and the API adds an IKEv2 entry only to the servers that still accept it. These tests
/// check that no other server reports IKEv2 support, while WireGuard keeps its existing rules.
@Suite("Per-protocol entries")
struct PerProtocolEntriesTests {
    private let entryIp = "10.0.0.1"
    private let relayIp = "9.9.9.9"

    private func endpoint(entries: PerProtocolEntries?) -> ServerEndpoint {
        ServerEndpoint(
            id: "endpoint",
            entryIp: entryIp,
            exitIp: "10.0.0.2",
            domain: "ch-01.protonvpn.net",
            status: 1,
            label: nil,
            x25519PublicKey: nil,
            protocolEntries: entries
        )
    }

    // MARK: - IKEv2

    @Test("A server without entries supports every protocol except IKEv2")
    func serverWithoutEntriesDoesNotSupportIKEv2() {
        let endpoint = endpoint(entries: nil)

        #expect(endpoint.supportedProtocols == [.wireGuardUDP, .wireGuardTCP, .wireGuardTLS])
        #expect(endpoint.entryIp(using: .ike) == nil)
        #expect(endpoint.entryIp(using: .wireGuard(.udp)) == entryIp)
    }

    @Test("An empty IKEv2 entry makes the server support IKEv2 through its entry IP")
    func emptyIKEv2EntryUsesEntryIp() {
        let endpoint = endpoint(entries: [
            .wireGuard(.udp): .init(ipv4: nil, ports: nil),
            .ike: .init(ipv4: nil, ports: nil),
        ])

        #expect(endpoint.entryIp(using: .ike) == entryIp)
    }

    @Test("An IKEv2 entry with an address makes the server use that address")
    func ikev2EntryWithAddressUsesThatAddress() {
        let endpoint = endpoint(entries: [.ike: .init(ipv4: relayIp, ports: nil)])

        #expect(endpoint.entryIp(using: .ike) == relayIp)
    }

    @Test("Entries that list only WireGuard leave out IKEv2")
    func wireGuardOnlyEntriesLeaveOutIKEv2() {
        let endpoint = endpoint(entries: [
            .wireGuard(.udp): .init(ipv4: nil, ports: nil),
            .wireGuard(.tcp): .init(ipv4: nil, ports: nil),
            .wireGuard(.tls): .init(ipv4: nil, ports: nil),
        ])

        #expect(endpoint.supportedProtocols == [.wireGuardUDP, .wireGuardTCP, .wireGuardTLS])
        #expect(endpoint.entryIp(using: .wireGuard(.tls)) == entryIp)
    }

    /// An entry with an address used to mean the server supports every protocol, IKEv2 included.
    @Test("WireGuard entries with an address do not make the server support IKEv2")
    func wireGuardEntriesWithAddressLeaveOutIKEv2() {
        let endpoint = endpoint(entries: [.wireGuard(.tls): .init(ipv4: relayIp, ports: nil)])

        #expect(endpoint.supportedProtocols == [.wireGuardUDP, .wireGuardTCP, .wireGuardTLS])
        #expect(endpoint.entryIp(using: .wireGuard(.tls)) == relayIp)
        #expect(endpoint.entryIp(using: .wireGuard(.udp)) == entryIp)
    }

    @Test("A null entry counts as no entry")
    func nullEntryCountsAsNoEntry() throws {
        let json = #"{"WireGuardUDP": {"IPv4": "9.9.9.9"}, "IKEv2": null}"#
        let entries = try JSONDecoder().decode(PerProtocolEntries.self, from: Data(json.utf8))
        let endpoint = endpoint(entries: entries)

        #expect(entries.rawValue.keys.sorted() == ["WireGuardUDP"])
        #expect(endpoint.entryIp(using: .ike) == nil)
        #expect(endpoint.entryIp(using: .wireGuard(.tcp)) == entryIp)
    }

    // MARK: - Parsing

    /// Before this change, one null entry made the parser discard the whole field, relay addresses included.
    @Test("A null entry in the API response keeps the entries next to it")
    func nullEntryKeepsTheEntriesNextToIt() throws {
        let json = """
        {"ID": "server", "EntryIP": null, "ExitIP": "10.0.0.2", "Domain": "ch-01.protonvpn.net", "Status": 1,
         "EntryPerProtocol": {"WireGuardUDP": {"IPv4": "9.9.9.9"}, "IKEv2": null}}
        """
        let dictionary = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])

        let serverIp = try ServerIp(dic: dictionary)

        #expect(serverIp.protocolEntries?.rawValue.keys.sorted() == ["WireGuardUDP"])
        #expect(serverIp.entryIp(using: .wireGuard(.udp)) == relayIp)
        #expect(!serverIp.supports(vpnProtocol: .ike))
    }
}
