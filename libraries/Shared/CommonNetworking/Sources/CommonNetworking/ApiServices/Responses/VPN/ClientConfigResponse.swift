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

import Dependencies
import Foundation
import Hermes

public struct ClientConfigResponse {
    let clientConfig: ClientConfig

    public init(clientConfig: ClientConfig) {
        self.clientConfig = clientConfig
    }

    enum CodingKeys: String, CodingKey {
        case defaultPorts
        case featureFlags
        case serverRefreshInterval
        case smartProtocol
        case ratingSettings
    }

    struct DefaultPorts: Codable {
        struct ProtocolPorts: Codable, Equatable {
            let udp: [Int]
            let tcp: [Int]
            let tls: [Int]

            enum CodingKeys: String, CodingKey {
                case udp = "UDP"
                case tcp = "TCP"
                case tls = "TLS"
            }

            init(udp: [Int], tcp: [Int], tls: [Int]) {
                self.udp = udp
                self.tcp = tcp
                self.tls = tls
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.udp = try container.decodeIfPresent([Int].self, forKey: .udp) ?? []
                self.tcp = try container.decodeIfPresent([Int].self, forKey: .tcp) ?? []
                self.tls = try container.decodeIfPresent([Int].self, forKey: .tls) ?? []
            }
        }

        let openVPN: ProtocolPorts?
        let wireGuard: ProtocolPorts?
    }
}

extension ClientConfigResponse: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let featureFlags = try container.decode(FeatureFlags.self, forKey: .featureFlags)
        let serverRefreshInterval = try container.decode(Int.self, forKey: .serverRefreshInterval)
        let defaultPorts = try container.decode(DefaultPorts.self, forKey: .defaultPorts)

        let wireguardPorts = defaultPorts.wireGuard
        let (wireguardUdp, wireguardTcp, wireguardTls) = (
            wireguardPorts?.udp,
            wireguardPorts?.tcp,
            wireguardPorts?.tls ?? wireguardPorts?.tcp
        )

//        @Dependency(\.hermesClient) var hermesClient
//        @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
//
//        let hermesIsEnabled: Bool = hermesClient.isEnabled().wrappedValue
//        let hermesIsAllowed = featureAuthorizerProvider.authorizer(for: HermesFeature.self)().isAllowed
//
//        var hermesResolvers: [HermesResolver] = [.proton]
//        if hermesIsEnabled, hermesIsAllowed {
//            hermesResolvers.insert(contentsOf: hermesClient.activeHermesResolvers().wrappedValue, at: 0)
//        }

        let wireguardConfig = WireguardConfig(
            defaultUdpPorts: wireguardUdp,
            defaultTcpPorts: wireguardTcp,
            defaultTlsPorts: wireguardTls,
            dns: [] // hermesResolvers.map(\.location)
        )

        let smartProtocolConfig = try container.decode(SmartProtocolConfig.self, forKey: .smartProtocol)
        let ratingSettings = try container.decodeIfPresent(RatingSettings.self, forKey: .ratingSettings) ?? RatingSettings()
        // decoded directly from the parent object without a container. See `ServerChangeConfig` docs for more info
        let serverChangeConfig = (try? ServerChangeConfig(from: decoder)) ?? ServerChangeConfig()

        self.clientConfig = ClientConfig(
            featureFlags: featureFlags,
            serverRefreshInterval: serverRefreshInterval,
            wireGuardConfig: wireguardConfig,
            smartProtocolConfig: smartProtocolConfig,
            ratingSettings: ratingSettings,
            serverChangeConfig: serverChangeConfig
        )
    }
}

#if DEBUG

    // MARK: API Response Encodable Conformances

    extension ClientConfigResponse: Encodable {
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(clientConfig.featureFlags, forKey: .featureFlags)
            try container.encode(clientConfig.serverRefreshInterval, forKey: .serverRefreshInterval)
            try container.encode(clientConfig.smartProtocolConfig, forKey: .smartProtocol)
            try container.encode(clientConfig.ratingSettings, forKey: .ratingSettings)
            // encoded directly into the parent object without a container. See `ServerChangeConfig` docs for more info
            try clientConfig.serverChangeConfig.encode(to: encoder)

            let defaultPorts = ClientConfigResponse.DefaultPorts(
                openVPN: nil,
                wireGuard: .init(
                    udp: clientConfig.wireGuardConfig.defaultUdpPorts,
                    tcp: clientConfig.wireGuardConfig.defaultTcpPorts,
                    tls: []
                )
            )

            try container.encode(defaultPorts, forKey: .defaultPorts)
        }
    }
#endif
