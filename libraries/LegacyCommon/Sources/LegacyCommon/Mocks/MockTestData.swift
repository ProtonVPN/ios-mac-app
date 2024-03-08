//
//  Created on 2022-07-13.
//
//  Copyright (c) 2022 Proton AG
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

#if DEBUG
import Foundation

public struct MockTestData {
    public struct VPNLocationResponse: Codable, Equatable {
        let ip: String
        let country: String
        let isp: String

        enum CodingKeys: String, CodingKey {
            case ip = "IP"
            case country = "Country"
            case isp = "ISP"
        }

        public static let mock = VPNLocationResponse(ip: "123.123.123.123", country: "USA", isp: "GreedyCorp, Inc.")
    }

    public init() { }

    /// free server with relatively high latency score and not under maintenance.
    public var server1 = ServerModel(id: "abcd",
                              name: "free server",
                              domain: "swiss.protonvpn.ch",
                              load: 15,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .freeTier,
                              feature: .zero,
                              city: "Palézieux",
                              ips: [.init(id: "abcd", entryIp: "10.0.0.1", exitIp: "10.0.0.2",
                                          domain: "swiss.protonvpn.ch", status: 1,
                                          x25519PublicKey: "this is a public key".data(using: .utf8)!.base64EncodedString())],
                              score: 50,
                              status: 1, // 0 == under maintenance
                              location: ServerLocation(lat: 46.33, long: 6.5),
                              hostCountry: "Switzerland",
                              translatedCity: "Not The Eyes",
                              gatewayName: nil
    )

    /// free server with relatively low latency score and not under maintenance.
    public var server2 = ServerModel(id: "efgh",
                              name: "other free server",
                              domain: "swiss2.protonvpn.ch",
                              load: 80,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .freeTier,
                              feature: .zero,
                              city: "Gland",
                              ips: [.init(id: "efgh", entryIp: "10.0.0.3", exitIp: "10.0.0.4",
                                          domain: "swiss2.protonvpn.ch", status: 1,
                                          x25519PublicKey: "this is another public key".data(using: .utf8)!.base64EncodedString())],
                              score: 15,
                              status: 1,
                              location: ServerLocation(lat: 46.25, long: 6.16),
                              hostCountry: "Switzerland",
                              translatedCity: "Anatomy",
                              gatewayName: nil
    )

    /// same server as server 2, but placed under maintenance.
    public var server2UnderMaintenance = ServerModel(
                              id: "efgh",
                              name: "other free server",
                              domain: "swiss2.protonvpn.ch",
                              load: 80,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .freeTier,
                              feature: .zero,
                              city: "Gland",
                              ips: [.init(id: "efgh", entryIp: "10.0.0.3", exitIp: "10.0.0.4",
                                          domain: "swiss2.protonvpn.ch", status: 0,
                                          x25519PublicKey: "this is another public key".data(using: .utf8)!.base64EncodedString())],
                              score: 15,
                              status: 0, // under maintenance
                              location: ServerLocation(lat: 46.25, long: 6.16),
                              hostCountry: "Switzerland",
                              translatedCity: "Anatomy",
                              gatewayName: nil
    )

    /// plus server with low latency score and p2p feature. not under maintenance.
    public var server3 = ServerModel(id: "ijkl",
                              name: "plus server",
                              domain: "swissplus.protonvpn.ch",
                              load: 42,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .paidTier,
                              feature: .zero,
                              city: "Zurich",
                              ips: [.init(id: "ijkl", entryIp: "10.0.0.5", exitIp: "10.0.0.6",
                                          domain: "swissplus.protonvpn.net", status: 1,
                                          x25519PublicKey: "plus public key".data(using: .utf8)!.base64EncodedString())],
                              score: 10,
                              status: 1,
                              location: .init(lat: 47.22, long: 8.32),
                              hostCountry: "Switzerland",
                              translatedCity: nil,
                              gatewayName: nil
    )

    /// plus server with IP override for Stealth protocol.
    public var server4 = ServerModel(id: "mnop",
                              name: "fancy plus server",
                              domain: "withrelay.protonvpn.ch",
                              load: 42,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .paidTier,
                              feature: .zero,
                              city: "Zurich",
                              ips: [.init(id: "mnop",
                                          entryIp: "10.0.0.7",
                                          exitIp: "10.0.0.8",
                                          domain: "withrelay.protonvpn.net",
                                          status: 1,
                                          protocolEntries: [.wireGuard(.tls): .init(ipv4: "10.0.0.9", ports: nil)])],
                              score: 10,
                              status: 1,
                              location: .init(lat: 47.22, long: 8.32),
                              hostCountry: "Switzerland",
                              translatedCity: nil,
                              gatewayName: nil
    )

    /// plus server with IP and port override for Stealth protocol.
    public var server5 = ServerModel(id: "qrst",
                              name: "ports plus server",
                              domain: "withrelay2.protonvpn.ch",
                              load: 42,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .paidTier,
                              feature: .zero,
                              city: "Zurich",
                              ips: [.init(id: "mnop",
                                          entryIp: "10.0.0.10",
                                          exitIp: "10.0.0.11",
                                          domain: "withrelay2.protonvpn.net",
                                          status: 1,
                                          protocolEntries: [.wireGuard(.tls): .init(ipv4: "10.0.1.12",
                                                                                    ports: [15213])])],
                              score: 10,
                              status: 1,
                              location: .init(lat: 47.22, long: 8.32),
                              hostCountry: "Switzerland",
                              translatedCity: nil,
                              gatewayName: nil
    )

    /// plus server which supports Stealth protocol only.
    public var server6 = ServerModel(id: "uvwx",
                              name: "exclusive plus server",
                              domain: "withrelay3.protonvpn.ch",
                              load: 42,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .paidTier,
                              feature: .zero,
                              city: "Zurich",
                              ips: [.init(id: "mnop",
                                          entryIp: "10.0.0.13",
                                          exitIp: "10.0.0.14",
                                          domain: "withrelay3.protonvpn.net",
                                          status: 1,
                                          protocolEntries: [.wireGuard(.tls): .init(ipv4: nil, ports: nil)])],
                              score: 10,
                              status: 1,
                              location: .init(lat: 47.22, long: 8.32),
                              hostCountry: "Switzerland",
                              translatedCity: nil,
                              gatewayName: nil
    )

    /// plus server which supports all the features.
    func server7(id: String = "yzab") -> ServerModel {
        .init(id: id,
              name: "exclusive plus server",
              domain: "withrelay3.protonvpn.ch",
              load: 42,
              entryCountryCode: "CH",
              exitCountryCode: "CH",
              tier: .paidTier,
              feature: [.ipv6, .p2p, .partner, .restricted, .secureCore, .streaming, .tor],
              city: "Zurich",
              ips: [.init(id: "mnop",
                          entryIp: "10.0.0.13",
                          exitIp: "10.0.0.14",
                          domain: "withrelay3.protonvpn.net",
                          status: 1,
                          protocolEntries: [.wireGuard(.tls): .init(ipv4: nil, ports: nil)])],
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
    public var server8 = ServerModel(id: "zyxw",
                              name: "stealthy server",
                              domain: "withrelay128.protonvpn.ch",
                              load: 42,
                              entryCountryCode: "CH",
                              exitCountryCode: "CH",
                              tier: .paidTier,
                              feature: .zero,
                              city: "Zurich",
                              ips: [.init(id: "mnop",
                                          entryIp: "10.0.0.13",
                                          exitIp: "10.0.0.14",
                                          domain: "withrelay3.protonvpn.net",
                                          status: 1,
                                          protocolEntries: [
                                            .wireGuard(.udp): .init(ipv4: "10.0.1.1", ports: nil),
                                            .openVpn(.udp): .init(ipv4: nil, ports: [1234, 5678])
                                          ])
                              ],
                              score: 10,
                              status: 1,
                              location: .init(lat: 47.22, long: 8.32),
                              hostCountry: "Switzerland",
                              translatedCity: nil,
                              gatewayName: nil
    )

    public var defaultClientConfig = ClientConfig(
        openVPNConfig: .init(defaultTcpPorts: [1234, 5678], defaultUdpPorts: [2345, 6789]),
        featureFlags: .allEnabled,
        serverRefreshInterval: 2 * 60,
        wireGuardConfig: .init(defaultUdpPorts: [12345, 65432], defaultTcpPorts: [12346, 65433]),
        smartProtocolConfig: .init(),
        ratingSettings: .init(),
        serverChangeConfig: ServerChangeConfig()
    )

    public lazy var clientConfigNoWireGuardTls = defaultClientConfig.with(featureFlags: .wireGuardTlsDisabled)
}

extension ClientConfig {
    public func with(featureFlags: FeatureFlags? = nil, smartProtocolConfig: SmartProtocolConfig? = nil) -> ClientConfig {
        return ClientConfig(
            openVPNConfig: openVPNConfig,
            featureFlags: featureFlags ?? self.featureFlags,
            serverRefreshInterval: serverRefreshInterval,
            wireGuardConfig: wireGuardConfig,
            smartProtocolConfig: smartProtocolConfig ?? self.smartProtocolConfig,
            ratingSettings: ratingSettings,
            serverChangeConfig: ServerChangeConfig()
        )
    }
}

extension FeatureFlags {
    public static let allDisabled: Self = .init(
        smartReconnect: false,
        vpnAccelerator: false,
        netShield: false,
        netShieldStats: false,
        streamingServicesLogos: false,
        portForwarding: false,
        moderateNAT: false,
        pollNotificationAPI: false,
        serverRefresh: false,
        guestHoles: false,
        safeMode: false,
        promoCode: false,
        wireGuardTls: false,
        enforceDeprecatedProtocols: false,
        showNewFreePlan: false,
        unsafeLanWarnings: false,
        mismatchedCertificateRecovery: false,
        localOverrides: nil
    )
    public static let allEnabled: Self = .init(
        smartReconnect: true,
        vpnAccelerator: true,
        netShield: true,
        netShieldStats: true,
        streamingServicesLogos: true,
        portForwarding: true,
        moderateNAT: true,
        pollNotificationAPI: true,
        serverRefresh: true,
        guestHoles: true,
        safeMode: true,
        promoCode: true,
        wireGuardTls: true,
        enforceDeprecatedProtocols: true,
        showNewFreePlan: true,
        unsafeLanWarnings: true,
        mismatchedCertificateRecovery: true,
        localOverrides: nil
    )

    public static let wireGuardTlsDisabled: Self = .allEnabled
        .disabling(\.wireGuardTls)
}

extension PartnerType {
    static func onePartner(logicalIDs: [String] = ["abcde"]) -> PartnerType {
        let partner = Partner(
            name: "Deutsche Welle",
            description: "Deutsche Welle, abbreviated to DW, is a German public, state-owned international broadcaster funded by the German federal tax budget.",
            iconURL: URL(string: "https://proton.me/favicon.ico"),
            logicalIDs: logicalIDs
        )

        return .init(
            type: "News",
            description: "descr",
            iconURL: URL(string: "https://proton.me/favicon.ico"),
            partners: [partner]
        )
    }
}

extension SmartProtocolConfig {
    public static let onlyWgTcpAndTls = SmartProtocolConfig(openVPN: false, iKEv2: false, wireGuardUdp: false, wireGuardTcp: true, wireGuardTls: true)
    public static let onlyIke = SmartProtocolConfig(openVPN: false, iKEv2: true, wireGuardUdp: false, wireGuardTcp: false, wireGuardTls: false)
}
#endif
