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

@testable import CommonNetworking
import Domain
import Foundation
import Testing

@Suite("Logicals response decoding")
struct LogicalsResponseDecodingTests {
    private func decode(_ json: String) throws -> LogicalsResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .decapitaliseFirstLetter
        return try decoder.decode(LogicalsResponse.self, from: Data(json.utf8))
    }

    /// Decodes a response that is expected to carry readable servers.
    private func decodeServers(_ json: String) throws -> [LogicalDTO] {
        let response = try decode(json)
        guard case let .servers(servers) = response else {
            throw UnexpectedResponse(response: response)
        }
        return servers
    }

    private struct UnexpectedResponse: Error {
        let response: LogicalsResponse
    }

    /// One logical wrapping a single endpoint, so each test only has to say what that endpoint looks like.
    private func payload(endpoint: String) -> String {
        """
        {"LogicalServers": [{
            "ID": "logical", "Name": "CH#1", "Domain": "ch-01.protonvpn.com",
            "Load": 15, "Score": 1.5, "Status": 1, "Tier": 0, "Features": 0,
            "EntryCountry": "CH", "ExitCountry": "CH", "City": "Zurich",
            "Location": {"Lat": 47.2, "Long": 8.3},
            "Servers": [\(endpoint)]
        }]}
        """
    }

    @Test("Reads a plain endpoint")
    func readsAPlainEndpoint() throws {
        let servers = try decodeServers(
            payload(
                endpoint: """
                {"ID": "endpoint", "EntryIP": "1.2.3.4", "ExitIP": "1.2.3.5",
                 "Domain": "ch-01.protonvpn.com", "Status": 1, "Label": "2",
                 "X25519PublicKey": "public-key"}
                """
            )
        )

        let endpoint = try #require(servers.first?.vpnServer.endpoints.first)
        #expect(endpoint.entryIp == "1.2.3.4")
        #expect(endpoint.exitIp == "1.2.3.5")
        #expect(endpoint.label == "2")
        #expect(endpoint.x25519PublicKey == "public-key")
        #expect(endpoint.supportedProtocols == .all)
    }

    @Test("Reads per-protocol addresses and ports")
    func readsPerProtocolAddressesAndPorts() throws {
        let servers = try decodeServers(
            payload(
                endpoint: """
                {"ID": "endpoint", "EntryIP": null, "ExitIP": "1.2.3.5",
                 "Domain": "ch-01.protonvpn.com", "Status": 1,
                 "EntryPerProtocol": {
                     "WireGuardUDP": {"IPv4": "1.1.1.1", "Ports": [1234]},
                     "WireGuardTLS": {"IPv4": "1.1.1.3"}
                 }}
                """
            )
        )

        let endpoint = try #require(servers.first?.vpnServer.endpoints.first)
        #expect(endpoint.entryIp == nil)
        #expect(endpoint.entryIp(using: .wireGuard(.udp)) == "1.1.1.1")
        #expect(endpoint.entryIp(using: .wireGuard(.tls)) == "1.1.1.3")
        #expect(endpoint.overridePorts(using: .wireGuard(.udp)) == [1234])
        #expect(endpoint.supportedProtocols == [.wireGuardUDP, .wireGuardTLS])
    }

    /// The UDP address must survive the `null` sitting next to it,
    /// otherwise the endpoint reports no address at all and the connection cannot be configured.
    @Test("Keeps the addresses that sit next to a null per-protocol entry")
    func keepsAddressesNextToANullEntry() throws {
        let servers = try decodeServers(
            payload(
                endpoint: """
                {"ID": "endpoint", "EntryIP": null, "ExitIP": "1.2.3.5",
                 "Domain": "ch-01.protonvpn.com", "Status": 1,
                 "EntryPerProtocol": {"WireGuardUDP": {"IPv4": "1.1.1.1"}, "IKEv2": null}}
                """
            )
        )

        let endpoint = try #require(servers.first?.vpnServer.endpoints.first)
        #expect(endpoint.entryIp(using: .wireGuard(.udp)) == "1.1.1.1")
        #expect(endpoint.supportedProtocols == .wireGuardUDP)
    }

    @Test("An endpoint with no address supports no protocols")
    func endpointWithoutAnyAddressSupportsNoProtocols() throws {
        let servers = try decodeServers(
            payload(
                endpoint: """
                {"ID": "endpoint", "EntryIP": null, "ExitIP": "1.2.3.5",
                 "Domain": "ch-01.protonvpn.com", "Status": 1}
                """
            )
        )

        let endpoint = try #require(servers.first?.vpnServer.endpoints.first)
        #expect(endpoint.entryIp == nil)
        #expect(endpoint.supportedProtocols == .zero)
    }

    @Test("Reads the translated city and the state")
    func readsTranslationsAndState() throws {
        let servers = try decodeServers(
            """
            {"LogicalServers": [{
                "ID": "logical", "Name": "US-CO#1", "Domain": "us-co-01.protonvpn.com",
                "Load": 15, "Score": 1.5, "Status": 1, "Tier": 2, "Features": 0,
                "EntryCountry": "US", "ExitCountry": "US", "City": "Denver", "State": "Colorado",
                "HostCountry": "US", "GatewayName": "Gateway",
                "Translations": {"City": "Denver!"},
                "Location": {"Lat": 39.7, "Long": -104.9},
                "Servers": [{"ID": "endpoint", "EntryIP": "1.2.3.4", "ExitIP": "1.2.3.5",
                             "Domain": "us-co-01.protonvpn.com", "Status": 1}]
            }]}
            """
        )

        let logical = try #require(servers.first?.vpnServer.logical)
        #expect(logical.state == "Colorado")
        #expect(logical.translatedCity == "Denver!")
        #expect(logical.hostCountry == "US")
        #expect(logical.gatewayName == "Gateway")
    }

    @Test("Skips a server it cannot read and keeps the rest")
    func skipsUnreadableServers() throws {
        let servers = try decodeServers(
            """
            {"LogicalServers": [
                {"ID": "broken", "Name": "CH#1"},
                {"ID": "logical", "Name": "CH#2", "Domain": "ch-02.protonvpn.com",
                 "Load": 15, "Score": 1.5, "Status": 1, "Tier": 0, "Features": 0,
                 "EntryCountry": "CH", "ExitCountry": "CH",
                 "Location": {"Lat": 47.2, "Long": 8.3},
                 "Servers": [{"ID": "endpoint", "EntryIP": "1.2.3.4", "ExitIP": "1.2.3.5",
                              "Domain": "ch-02.protonvpn.com", "Status": 1}]}
            ]}
            """
        )

        #expect(servers.map(\.id) == ["logical"])
    }

    // MARK: - Responses that carry no usable server

    // The next two both come back without a server to connect to, for opposite reasons. An account with
    // nothing assigned has to log the user out; a payload the app can no longer read must not, or one
    // API change logs everybody out.

    @Test("A response that lists no servers reads as empty")
    func aResponseListingNoServersReadsAsEmpty() throws {
        let response = try decode(#"{"LogicalServers": []}"#)

        guard case .empty = response else {
            Issue.record("Expected an empty response, got \(response)")
            return
        }
    }

    @Test("A response whose every server fails to decode reads as unreadable")
    func aResponseWithNoReadableServerReadsAsUnreadable() throws {
        let response = try decode(
            """
            {"LogicalServers": [
                {"ID": "broken-1", "Name": "CH#1"},
                {"ID": "broken-2", "Name": "CH#2"}
            ]}
            """
        )

        guard case let .unreadable(receivedServerCount) = response else {
            Issue.record("Expected an unreadable response, got \(response)")
            return
        }
        #expect(receivedServerCount == 2)
    }
}
