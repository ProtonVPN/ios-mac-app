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

#if DEBUG
    import Domain
    import DomainTestSupport
    @testable import ExtensionManager
    import Foundation
    import Testing
    import VPNCoreTypes

    struct ServerPeerInfoTests {
        private let config = WireguardConfig(
            defaultUdpPorts: [51820],
            defaultTcpPorts: [443],
            defaultTlsPorts: [8443]
        )

        private func server(
            entryIp: String?,
            protocolEntries: PerProtocolEntries? = nil,
            publicKey: String? = "public-key"
        ) -> Server {
            Server(
                logical: .mock,
                endpoint: ServerEndpoint(
                    id: "endpoint",
                    entryIp: entryIp,
                    exitIp: "5.6.7.8",
                    domain: "node.mock.protonvpn.net",
                    status: 1,
                    label: "2",
                    x25519PublicKey: publicKey,
                    protocolEntries: protocolEntries
                )
            )
        }

        @Test
        func buildsOneDefaultPeerCarryingEveryTransportsPorts() throws {
            let peers = try server(entryIp: "1.2.3.4").peerInfo(using: config)

            #expect(peers.count == 1)
            #expect(peers[0].serverIP == "1.2.3.4")
            #expect(peers[0].serverPublicKey == "public-key")
            #expect(peers[0].udpPorts == [51820])
            #expect(peers[0].tcpPorts == [443])
            #expect(peers[0].tlsPorts == [8443])
            #expect(peers[0].exitLabel == "2")
            #expect(peers[0].serverName == "node.mock.protonvpn.net")
        }

        @Test
        func honorsPerProtocolPortOverridesOnTheDefaultPeer() throws {
            let peers = try server(
                entryIp: "1.2.3.4",
                protocolEntries: [.wireGuard(.tcp): .init(ipv4: nil, ports: [8080])]
            ).peerInfo(using: config)

            #expect(peers.count == 1)
            #expect(peers[0].serverIP == "1.2.3.4")
            #expect(peers[0].tcpPorts == [8080])
            #expect(peers[0].udpPorts.isEmpty)
            #expect(peers[0].tlsPorts.isEmpty)
        }

        @Test
        func splitsOffAPeerForEachTransportWithItsOwnAddress() throws {
            let peers = try server(
                entryIp: "1.2.3.4",
                protocolEntries: [.wireGuard(.tls): .init(ipv4: "9.9.9.9", ports: [4433])]
            ).peerInfo(using: config)

            #expect(peers.count == 2)

            let defaultPeer = try #require(peers.first { $0.serverIP == "1.2.3.4" })
            #expect(defaultPeer.udpPorts == [51820])
            #expect(defaultPeer.tcpPorts == [443])
            #expect(defaultPeer.tlsPorts.isEmpty)

            let tlsPeer = try #require(peers.first { $0.serverIP == "9.9.9.9" })
            #expect(tlsPeer.tlsPorts == [4433])
            #expect(tlsPeer.udpPorts.isEmpty)
            #expect(tlsPeer.tcpPorts.isEmpty)
            #expect(tlsPeer.serverName == "node.mock.protonvpn.net")
        }

        /// Every transport has its own address, so there is no default peer to build even though the API
        /// sent no `EntryIP`
        @Test
        func buildsOnlyOverriddenPeersWhenThereIsNoDefaultAddress() throws {
            let peers = try server(
                entryIp: nil,
                protocolEntries: [
                    .wireGuard(.udp): .init(ipv4: "1.1.1.1", ports: nil),
                    .wireGuard(.tcp): .init(ipv4: "1.1.1.2", ports: nil),
                    .wireGuard(.tls): .init(ipv4: "1.1.1.3", ports: nil),
                ]
            ).peerInfo(using: config)

            #expect(peers.count == 3)
            #expect(Set(peers.map(\.serverIP)) == ["1.1.1.1", "1.1.1.2", "1.1.1.3"])
            #expect(try #require(peers.first { $0.serverIP == "1.1.1.1" }).udpPorts == [51820])
        }

        @Test
        func buildsThePeerForTheOneTransportWithAnAddress() throws {
            let peers = try server(
                entryIp: nil,
                protocolEntries: [.wireGuard(.udp): .init(ipv4: "1.1.1.1", ports: [1234])]
            ).peerInfo(using: config)

            #expect(peers.count == 1)
            #expect(peers[0].serverIP == "1.1.1.1")
            #expect(peers[0].udpPorts == [1234])
            #expect(peers[0].tcpPorts.isEmpty)
            #expect(peers[0].tlsPorts.isEmpty)
        }

        @Test
        func reportsEntryIpMissingWhenTheEndpointHasNoAddressAtAll() {
            #expect(throws: ManagerConfigurationError.entryIpMissing) {
                try server(entryIp: nil).peerInfo(using: config)
            }
        }

        @Test
        func reportsEntryIpMissingWhenEveryEntryFallsBackToAnAbsentDefault() {
            #expect(throws: ManagerConfigurationError.entryIpMissing) {
                try server(
                    entryIp: nil,
                    protocolEntries: [.wireGuard(.udp): .init(ipv4: nil, ports: [1234])]
                ).peerInfo(using: config)
            }
        }

        @Test
        func reportsAMissingPublicKeyRatherThanBuildingAPeerWithoutOne() {
            #expect(throws: ManagerConfigurationError.emptyServerPublicKey) {
                try server(entryIp: "1.2.3.4", publicKey: nil).peerInfo(using: config)
            }
        }

        @Test
        func reportsAMissingPublicKeyOnOverriddenPeersToo() {
            #expect(throws: ManagerConfigurationError.emptyServerPublicKey) {
                try server(
                    entryIp: nil,
                    protocolEntries: [.wireGuard(.udp): .init(ipv4: "1.1.1.1", ports: nil)],
                    publicKey: nil
                ).peerInfo(using: config)
            }
        }
    }
#endif
