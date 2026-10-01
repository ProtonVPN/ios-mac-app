//
//  Created on 01/10/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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
import Foundation
import Testing
@testable import VPNNetworking
import VPNShared

@Suite("Smart Protocol")
struct SmartProtocolTests {
    private let wireguardConfig = WireguardConfig(
        defaultUdpPorts: [51820],
        defaultTcpPorts: [443],
        defaultTlsPorts: [8443]
    )

    @Test("Smart Protocol never checks or chooses IKEv2, even on a server that still accepts it")
    func neverUsesIKEv2() async {
        let resolver = StubCheckerResolver()
        let keeper = server(entries: [
            .ike: .init(ipv4: nil, ports: nil),
            .wireGuard(.udp): .init(ipv4: nil, ports: nil),
        ])

        let (vpnProtocol, ports) = await bestProtocol(on: keeper, resolver: resolver)

        #expect(!resolver.requestedProtocols.contains(.ike))
        #expect(vpnProtocol == .wireGuard(.udp))
        #expect(ports == [51820])
    }

    @Test("A config that enables only IKEv2 still connects with WireGuard")
    func onlyIKEv2InConfigFallsBackToWireGuard() async {
        let resolver = StubCheckerResolver()
        let config = SmartProtocolConfig(iKEv2: true, wireGuardUdp: false, wireGuardTcp: false, wireGuardTls: false)

        let (vpnProtocol, ports) = await bestProtocol(
            on: server(entries: allWireGuard),
            resolver: resolver,
            config: config
        )

        #expect(resolver.requestedProtocols.isEmpty)
        #expect(vpnProtocol == .wireGuard(.udp))
        #expect(ports == [51820])
    }

    @Test("The most preferred transport that passes its check wins")
    func preferredAvailableTransportWins() async {
        let resolver = StubCheckerResolver(available: [.wireGuard(.tcp): [443], .wireGuard(.tls): [8443]])

        let (vpnProtocol, ports) = await bestProtocol(on: server(entries: allWireGuard), resolver: resolver)

        #expect(vpnProtocol == .wireGuard(.tls))
        #expect(ports == [8443])
    }

    @Test("When every check fails, a relay that only serves WireGuard TLS falls back to it")
    func tlsRelayFallsBackToTLS() async {
        let relay = server(entries: [.wireGuard(.tls): .init(ipv4: "10.0.0.1", ports: nil)], entryIp: nil)

        let (vpnProtocol, ports) = await bestProtocol(on: relay, resolver: StubCheckerResolver())

        #expect(vpnProtocol == .wireGuard(.tls))
        #expect(ports == [8443])
    }

    @Test("When every check fails, a server that lists no WireGuard transport gets WireGuard UDP")
    func serverWithoutWireGuardFallsBackToUDP() async {
        let ikev2Only = server(entries: [.ike: .init(ipv4: nil, ports: nil)])

        let (vpnProtocol, ports) = await bestProtocol(on: ikev2Only, resolver: StubCheckerResolver())

        #expect(vpnProtocol == .wireGuard(.udp))
        #expect(ports == [51820])
    }

    // MARK: - Helpers

    private var allWireGuard: PerProtocolEntries {
        [
            .wireGuard(.udp): .init(ipv4: nil, ports: nil),
            .wireGuard(.tcp): .init(ipv4: nil, ports: nil),
            .wireGuard(.tls): .init(ipv4: nil, ports: nil),
        ]
    }

    private func server(entries: PerProtocolEntries, entryIp: String? = "1.2.3.4") -> ServerIp {
        ServerIp(
            id: "id",
            entryIp: entryIp,
            exitIp: "5.6.7.8",
            domain: "node.protonvpn.net",
            status: 1,
            protocolEntries: entries
        )
    }

    private func bestProtocol(
        on server: ServerIp,
        resolver: StubCheckerResolver,
        config: SmartProtocolConfig = .init(iKEv2: true, wireGuardUdp: true, wireGuardTcp: true, wireGuardTls: true)
    ) async -> (VpnProtocol, [Int]) {
        let smartProtocol = SmartProtocolImplementation(
            availabilityCheckerResolver: resolver,
            smartProtocolConfig: config,
            wireguardConfig: wireguardConfig
        )
        return await withCheckedContinuation { continuation in
            smartProtocol.determineBestProtocol(server: server) { vpnProtocol, ports in
                continuation.resume(returning: (vpnProtocol, ports))
            }
        }
    }
}

/// Hands out checkers that report the given protocols as available on the given ports, and every other protocol as
/// unavailable. It records which protocols Smart Protocol asked for.
private final class StubCheckerResolver: AvailabilityCheckerResolver {
    private let available: [VpnProtocol: [Int]]
    private(set) var requestedProtocols: [VpnProtocol] = []

    init(available: [VpnProtocol: [Int]] = [:]) {
        self.available = available
    }

    func availabilityChecker(for vpnProtocol: VpnProtocol) -> SmartProtocolAvailabilityChecker {
        requestedProtocols.append(vpnProtocol)
        return StubChecker(vpnProtocol: vpnProtocol, availablePorts: available[vpnProtocol])
    }
}

private final class StubChecker: SmartProtocolAvailabilityChecker {
    let vpnProtocol: VpnProtocol
    let defaultPorts: [Int] = []
    private let availablePorts: [Int]?

    init(vpnProtocol: VpnProtocol, availablePorts: [Int]?) {
        self.vpnProtocol = vpnProtocol
        self.availablePorts = availablePorts
    }

    func checkAvailability(server _: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        completion(availablePorts.map { .available(ports: $0) } ?? .unavailable)
    }

    func ping(
        protocolName _: String,
        server _: ServerIp,
        port _: Int,
        timeout _: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        completion(false)
    }
}
