//
//  Created on 29/01/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Foundation

import Domain

public enum TestData {
    public static func createMockServer(
        withID id: String,
        tier: Int = 0,
        load: Int = 0,
        score: Double = 1,
        status: Int = 1
    ) -> VPNServer {
        return VPNServer(
            logical: .init(
                id: id,
                name: id,
                domain: "a",
                load: load,
                entryCountryCode: "CH",
                exitCountryCode: "CH",
                tier: tier,
                score: score,
                status: status,
                feature: .zero,
                city: nil,
                hostCountry: nil,
                translatedCity: nil,
                latitude: 47.22,
                longitude: 8.32,
                gatewayName: nil
            ),
            endpoints: [
                Domain.ServerEndpoint(
                    id: "endpoint\(id)",
                    entryIp: nil,
                    exitIp: "1",
                    domain: "a",
                    status: status,
                    label: nil,
                    x25519PublicKey: "",
                    protocolEntries: nil
                )
            ]
        )
    }

    public static let serverWithMultipleEndpointsAndOverrides = VPNServer(
        logical: .init(
            id: "overridesPlusLogical",
            name: "overridesPlusServer",
            domain: "withrelay2.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: 2,
            score: 19,
            status: 1,
            feature: [.tor, .p2p],
            city: "Zurich",
            hostCountry: "Switzerland",
            translatedCity: nil,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        ),
        endpoints: [
            ServerEndpoint(
                id: "overridesPlusEndpoint",
                entryIp: "10.0.0.10",
                exitIp: "10.0.0.11",
                domain: "withrelay2.protonvpn.net",
                status: 1,
                label: nil,
                x25519PublicKey: "",
                protocolEntries: [
                    .openVpn(.udp): .init(ipv4: "10.0.1.12", ports: [25565]),
                    .wireGuard(.tls): .init(ipv4: "10.0.2.12", ports: [32400])
                ]
            ),
            ServerEndpoint(
                id: "standardEnpoint",
                entryIp: "10.0.1.10",
                exitIp: "10.0.1.11",
                domain: "withrelay2.protonvpn.net",
                status: 1,
                label: nil,
                x25519PublicKey: "",
                protocolEntries: nil
            )
        ]
    )

    // Only supports IKE and Stealth, since one of the ipv4 of one of the overrides is nil
    public static let serverWithLimitedProtocolSupport = VPNServer(
        logical: .init(
            id: "overridesPlusLogical",
            name: "overridesPlusServer",
            domain: "withrelay2.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: 2,
            score: 19,
            status: 1,
            feature: [.tor, .p2p],
            city: "Zurich",
            hostCountry: "Switzerland",
            translatedCity: nil,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        ),
        endpoints: [
            ServerEndpoint(
                id: "overridesPlusEndpoint",
                entryIp: "10.0.0.10",
                exitIp: "10.0.0.11",
                domain: "withrelay2.protonvpn.net",
                status: 1,
                label: nil,
                x25519PublicKey: "",
                protocolEntries: [
                    .ike: .init(ipv4: nil, ports: [25565]),
                    .wireGuard(.tls): .init(ipv4: "10.0.2.12", ports: [32400])
                ]
            )
        ]
    )

    public static let serverWithNoOverrides = VPNServer(
        logical: .init(
            id: "overridesPlusLogical",
            name: "overridesPlusServer",
            domain: "withrelay2.protonvpn.ch",
            load: 42,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: 2,
            score: 19,
            status: 1,
            feature: [.tor, .p2p],
            city: "Zurich",
            hostCountry: "Switzerland",
            translatedCity: nil,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        ),
        endpoints: [
            ServerEndpoint(
                id: "overridesPlusEndpoint",
                entryIp: "10.0.0.10",
                exitIp: "10.0.0.11",
                domain: "withrelay2.protonvpn.net",
                status: 1,
                label: nil,
                x25519PublicKey: "",
                protocolEntries: nil
            )
        ]
    )
}
