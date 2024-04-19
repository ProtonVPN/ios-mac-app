//
//  ClientConfigResponse.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

struct ClientConfigResponse {
    enum PortType {
        static let UDP = "UDP"
        static let TCP = "TCP"
        static let TLS = "TLS"
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
        case ratingSettings
    }
}

extension ClientConfigResponse: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let featureFlags = try container.decode(FeatureFlags.self, forKey: .featureFlags)
        let serverRefreshInterval = try container.decode(Int.self, forKey: .serverRefreshInterval)
        let defaultPorts = try container.decode([String: [String: [Int]]].self, forKey: .defaultPorts)

        let wireguardPorts = defaultPorts[ProtocolType.WireGuard]
        let (wireguardUdp, wireguardTcp, wireguardTls) = (wireguardPorts?[PortType.UDP],
                                                          wireguardPorts?[PortType.TCP],
                                                          wireguardPorts?[PortType.TLS] ?? wireguardPorts?[PortType.TCP])
        let wireguardConfig = WireguardConfig(defaultUdpPorts: wireguardUdp,
                                              defaultTcpPorts: wireguardTcp,
                                              defaultTlsPorts: wireguardTls)

        let smartProtocolConfig = try container.decode(SmartProtocolConfig.self, forKey: .smartProtocol)
        let ratingSettings = try container.decodeIfPresent(RatingSettings.self, forKey: .ratingSettings) ?? RatingSettings()
        // decoded directly from the parent object without a container. See `ServerChangeConfig` docs for more info
        let serverChangeConfig = (try? ServerChangeConfig(from: decoder)) ?? ServerChangeConfig()

        clientConfig = ClientConfig(
            featureFlags: featureFlags,
            serverRefreshInterval: serverRefreshInterval,
            wireGuardConfig: wireguardConfig,
            smartProtocolConfig: smartProtocolConfig,
            ratingSettings: ratingSettings,
            serverChangeConfig: serverChangeConfig
        )
    }
}
