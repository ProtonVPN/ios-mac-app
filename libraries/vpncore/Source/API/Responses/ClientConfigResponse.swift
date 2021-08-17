//
//  ClientConfigResponse.swift
//  Core
//
//  Created by Igor Kulman on 17.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

struct ClientConfigResponse: Decodable {
    enum PortType {
        static let UDP = "UDP"
        static let TCP = "TCP"
    }
    enum ProtocolType {
        static let WireGuard = "WireGuard"
        static let OpenVPN = "OpenVPN"
    }

    let clientConfig: ClientConfig

    enum CodingKeys: String, CodingKey {
        case defaultPorts
        case featureFlags
        case serverRefreshInterval
        case smartProtocol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let featureFlags = try container.decode(FeatureFlags.self, forKey: .featureFlags)
        let serverRefreshInterval = try container.decode(Int.self, forKey: .serverRefreshInterval)
        let defaultPorts = try container.decode([String: [String: [Int]]].self, forKey: .defaultPorts)
        let openVPnConfig: OpenVpnConfig
        if let openVpnPorts = defaultPorts[ProtocolType.OpenVPN], let openVpnUDP = openVpnPorts[PortType.UDP], let openVpnTCP = openVpnPorts[PortType.TCP] {
            openVPnConfig = OpenVpnConfig(defaultTcpPorts: openVpnTCP, defaultUdpPorts: openVpnUDP)
        } else {
            openVPnConfig = OpenVpnConfig()
        }
        let wireguardConfig: WireguardConfig
        if let wireguardPorts = defaultPorts[ProtocolType.WireGuard], let wireguardUDP = wireguardPorts[PortType.UDP] {
            wireguardConfig = WireguardConfig(defaultPorts: wireguardUDP)
        } else {
            wireguardConfig = WireguardConfig()
        }
        let smartProtocolConfig = try container.decode(SmartProtocolConfig.self, forKey: .smartProtocol)

        clientConfig = ClientConfig(openVPNConfig: openVPnConfig, featureFlags: featureFlags, serverRefreshInterval: serverRefreshInterval, wireGuardConfig: wireguardConfig, smartProtocolConfig: smartProtocolConfig)
    }
}
