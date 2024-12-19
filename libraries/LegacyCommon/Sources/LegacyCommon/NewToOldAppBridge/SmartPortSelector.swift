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

import Foundation
import Dependencies
import Domain

struct SmartPortSelectorBridge: Sendable {
    var select: @Sendable (ServerEndpoint, ConnectionProtocol) async throws -> ServerEndpointPortResolution
}

struct ServerEndpointPortResolution: Sendable {
    let chosenProtocol: VpnProtocol
    let ports: [Int]
}

extension SmartPortSelectorBridge: DependencyKey {
    static let liveValue = {
        @Dependency(\.propertiesManager) var propertiesManager
        let resolver = AvailabilityCheckerResolverImplementation(wireguardConfig: propertiesManager.wireguardConfig)

        let smartProtocolImplementation = SmartProtocolImplementation(
            availabilityCheckerResolver: resolver,
            smartProtocolConfig: propertiesManager.smartProtocolConfig,
            wireguardConfig: propertiesManager.wireguardConfig
        )

        let smartPortSelector = SmartPortSelectorImplementation(
            wireguardUdpChecker: resolver.availabilityChecker(for: .wireGuard(.udp)),
            wireguardTcpChecker: resolver.availabilityChecker(for: .wireGuard(.tcp))
        )

        return SmartPortSelectorBridge(select: { endpoint, connectionProtocol in
            let serverIP = ServerIp(endpoint: endpoint)

            return await withCheckedContinuation { continuation in
                switch connectionProtocol {
                case .smartProtocol:
                    smartProtocolImplementation.determineBestProtocol(
                        server: ServerIp(endpoint: endpoint)
                    ) { chosenProtocol, ports in
                        let result = ServerEndpointPortResolution(chosenProtocol: chosenProtocol, ports: ports)
                        continuation.resume(returning: result)
                    }

                case .vpnProtocol(let vpnProtocol):
                    smartPortSelector.determineBestPort(for: vpnProtocol, on: serverIP) { ports in
                        let result = ServerEndpointPortResolution(chosenProtocol: vpnProtocol, ports: ports)
                        continuation.resume(returning: result)
                    }
                }
            }
        })
    }()
}

extension DependencyValues {
    var smartPortSelector: SmartPortSelectorBridge {
        get { self[SmartPortSelectorBridge.self] }
        set { self[SmartPortSelectorBridge.self] = newValue }
    }
}
