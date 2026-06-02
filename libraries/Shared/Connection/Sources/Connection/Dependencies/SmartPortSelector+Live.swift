//
//  Created on 19/12/2024.
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

import Dependencies
import Domain
import Sharing

extension SmartPortSelectorBridge: DependencyKey {
    public static let liveValue = SmartPortSelectorBridge(select: { endpoint, connectionProtocol in
        #if os(tvOS)
            let defaultTVOSProtocol: VpnProtocol = .wireGuard(.udp)
            @Dependency(\.connectionConfiguration) var configurationProvider
            let defaultPorts = configurationProvider.configuration().wireguardConfig.defaultUdpPorts
            let ports = endpoint.overridePorts(using: defaultTVOSProtocol) ?? defaultPorts
            return .init(chosenProtocol: defaultTVOSProtocol, ports: ports)
        #else
            @Shared(.wireguardConfig) var wireguardConfig
            @Shared(.smartProtocolConfig) var smartProtocolConfig
            let resolver = AvailabilityCheckerResolver(wireguardConfig: wireguardConfig)
            let serverIP = ServerIp(endpoint: endpoint)

            return await withCheckedContinuation { continuation in
                switch connectionProtocol {
                case .smartProtocol:
                    let smartProtocolImplementation = SmartProtocolImplementation(
                        availabilityCheckerResolver: resolver,
                        smartProtocolConfig: smartProtocolConfig,
                        wireguardConfig: wireguardConfig
                    )

                    smartProtocolImplementation.determineBestProtocol(server: serverIP) { chosenProtocol, ports in
                        let result = ServerEndpointPortResolution(chosenProtocol: chosenProtocol, ports: ports)
                        continuation.resume(returning: result)
                    }

                case let .vpnProtocol(vpnProtocol):
                    let smartPortSelector = SmartPortSelectorImplementation(
                        wireguardUdpChecker: resolver.availabilityChecker(for: .wireGuard(.udp)),
                        wireguardTcpChecker: resolver.availabilityChecker(for: .wireGuard(.tcp))
                    )

                    smartPortSelector.determineBestPort(for: vpnProtocol, on: serverIP) { ports in
                        let result = ServerEndpointPortResolution(chosenProtocol: vpnProtocol, ports: ports)
                        continuation.resume(returning: result)
                    }
                }
            }
        #endif
    })
}

private extension ServerIp {
    init(endpoint: Domain.ServerEndpoint) {
        self.init(
            id: endpoint.id,
            entryIp: endpoint.entryIp,
            exitIp: endpoint.exitIp,
            domain: endpoint.domain,
            status: endpoint.status,
            label: endpoint.label,
            x25519PublicKey: endpoint.x25519PublicKey,
            protocolEntries: endpoint.protocolEntries
        )
    }
}
