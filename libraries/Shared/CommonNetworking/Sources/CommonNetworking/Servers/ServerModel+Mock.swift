//
//  Created on 28/11/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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
    import Foundation

    public extension ServerModel {
        /// free server with relatively high latency score and not under maintenance.
        static var testServer1 = ServerModel(
            id: "abcd",
            name: "free server",
            domain: "swiss.protonvpn.ch",
            load: 15,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .freeTier,
            feature: .zero,
            city: "Palézieux",
            state: nil,
            ips: [.init(
                id: "abcd",
                entryIp: "10.0.0.1",
                exitIp: "10.0.0.2",
                domain: "swiss.protonvpn.ch",
                status: 1,
                x25519PublicKey: "this is a public key".data(using: .utf8)!.base64EncodedString()
            )],
            score: 50,
            status: 1, // 0 == under maintenance
            location: ServerLocation(lat: 46.33, long: 6.5),
            hostCountry: "Switzerland",
            translatedCity: "Not The Eyes",
            gatewayName: nil
        )

        /// free server with relatively low latency score and not under maintenance.
        static var testServer2 = ServerModel(
            id: "efgh",
            name: "other free server",
            domain: "swiss2.protonvpn.ch",
            load: 80,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .freeTier,
            feature: .zero,
            city: "Gland",
            state: nil,
            ips: [.init(
                id: "efgh",
                entryIp: "10.0.0.3",
                exitIp: "10.0.0.4",
                domain: "swiss2.protonvpn.ch",
                status: 1,
                x25519PublicKey: "this is another public key".data(using: .utf8)!.base64EncodedString()
            )],
            score: 15,
            status: 1,
            location: ServerLocation(lat: 46.25, long: 6.16),
            hostCountry: "Switzerland",
            translatedCity: "Anatomy",
            gatewayName: nil
        )

        /// same server as server 2, but placed under maintenance.
        static var testServer2UnderMaintenance = ServerModel(
            id: "efgh",
            name: "other free server",
            domain: "swiss2.protonvpn.ch",
            load: 80,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .freeTier,
            feature: .zero,
            city: "Gland",
            state: nil,
            ips: [.init(
                id: "efgh",
                entryIp: "10.0.0.3",
                exitIp: "10.0.0.4",
                domain: "swiss2.protonvpn.ch",
                status: 0,
                x25519PublicKey: "this is another public key".data(using: .utf8)!.base64EncodedString()
            )],
            score: 15,
            status: 0, // under maintenance
            location: ServerLocation(lat: 46.25, long: 6.16),
            hostCountry: "Switzerland",
            translatedCity: "Anatomy",
            gatewayName: nil
        )

        /// plus server with low latency score and p2p feature. not under maintenance.
        static var testServer3 = ServerModel(
            id: "ijkl",
            name: "plus server",
            domain: "swissplus.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .paidTier,
            feature: .zero,
            city: "Zurich",
            state: nil,
            ips: [.init(
                id: "ijkl",
                entryIp: "10.0.0.5",
                exitIp: "10.0.0.6",
                domain: "swissplus.protonvpn.net",
                status: 1,
                x25519PublicKey: "plus public key".data(using: .utf8)!.base64EncodedString()
            )],
            score: 10,
            status: 1,
            location: .init(lat: 47.22, long: 8.32),
            hostCountry: "Switzerland",
            translatedCity: nil,
            gatewayName: nil
        )

        /// plus server with IP override for Stealth protocol.
        static var testServer4 = ServerModel(
            id: "mnop",
            name: "fancy plus server",
            domain: "withrelay.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .paidTier,
            feature: .zero,
            city: "Zurich",
            state: nil,
            ips: [.init(
                id: "mnop",
                entryIp: "10.0.0.7",
                exitIp: "10.0.0.8",
                domain: "withrelay.protonvpn.net",
                status: 1,
                protocolEntries: [.wireGuard(.tls): .init(ipv4: "10.0.0.9", ports: nil)]
            )],
            score: 10,
            status: 1,
            location: .init(lat: 47.22, long: 8.32),
            hostCountry: "Switzerland",
            translatedCity: nil,
            gatewayName: nil
        )

        /// plus server with IP and port override for Stealth protocol.
        static var testServer5 = ServerModel(
            id: "qrst",
            name: "ports plus server",
            domain: "withrelay2.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .paidTier,
            feature: .zero,
            city: "Zurich",
            state: nil,
            ips: [.init(
                id: "qrst",
                entryIp: "10.0.0.10",
                exitIp: "10.0.0.11",
                domain: "withrelay2.protonvpn.net",
                status: 1,
                protocolEntries: [.wireGuard(.tls): .init(
                    ipv4: "10.0.1.12",
                    ports: [15213]
                )]
            )],
            score: 10,
            status: 1,
            location: .init(lat: 47.22, long: 8.32),
            hostCountry: "Switzerland",
            translatedCity: nil,
            gatewayName: nil
        )

        /// plus server which supports Stealth protocol only.
        static var testServer6 = ServerModel(
            id: "uvwx",
            name: "exclusive plus server",
            domain: "withrelay3.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .paidTier,
            feature: .zero,
            city: "Zurich",
            state: nil,
            ips: [.init(
                id: "uvwx",
                entryIp: "10.0.0.13",
                exitIp: "10.0.0.14",
                domain: "withrelay3.protonvpn.net",
                status: 1,
                protocolEntries: [.wireGuard(.tls): .init(ipv4: nil, ports: nil)]
            )],
            score: 10,
            status: 1,
            location: .init(lat: 47.22, long: 8.32),
            hostCountry: "Switzerland",
            translatedCity: nil,
            gatewayName: nil
        )

        /// plus server which supports all the features.
        static func testServer7(id: String = "yzab") -> ServerModel {
            .init(
                id: id,
                name: "exclusive plus server",
                domain: "withrelay3.protonvpn.ch",
                load: 42,
                entryCountryCode: "IS",
                exitCountryCode: "CH",
                tier: .paidTier,
                feature: [.ipv6, .p2p, .restricted, .secureCore, .streaming, .tor],
                city: "Zurich",
                state: nil,
                ips: [.init(
                    id: "yzab",
                    entryIp: "10.0.0.13",
                    exitIp: "10.0.0.14",
                    domain: "withrelay3.protonvpn.net",
                    status: 1,
                    protocolEntries: [.wireGuard(.tls): .init(ipv4: nil, ports: nil)]
                )],
                score: 10,
                status: 1,
                location: .init(lat: 47.22, long: 8.32),
                hostCountry: "Switzerland",
                translatedCity: nil,
                gatewayName: nil
            )
        }

        /// plus server which supports WireGuard protocol and OpenVPN UDP only.
        ///
        /// - Note: OpenVPNUDP uses the "EntryIP" field, WireGuard uses an explicit IP override.
        static var testServer8 = ServerModel(
            id: "zyxw",
            name: "stealthy server",
            domain: "withrelay128.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: .paidTier,
            feature: .zero,
            city: "Zurich",
            state: nil,
            ips: [.init(
                id: "zyxw",
                entryIp: "10.0.0.13",
                exitIp: "10.0.0.14",
                domain: "withrelay3.protonvpn.net",
                status: 1,
                protocolEntries: [
                    .wireGuard(.udp): .init(ipv4: "10.0.1.1", ports: nil),
                    .openVpn(.udp): .init(ipv4: nil, ports: [1234, 5678]),
                ]
            )],
            score: 10,
            status: 1,
            location: .init(lat: 47.22, long: 8.32),
            hostCountry: "Switzerland",
            translatedCity: nil,
            gatewayName: nil
        )

        var serverInfo: ServerInfo {
            let vpnServer = VPNServer(legacyModel: self)

            return ServerInfo(
                logical: vpnServer.logical,
                protocolSupport: vpnServer.supportedProtocols
            )
        }
    }
#endif
