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
import DependenciesMacros

import Connection
import Domain

// Protocol and port selection should ideally be implemented in the `Connection` package.
// Due to time constraints, let's reuse the legacy implementations until this is e.g. required on tvOS
// or we want to deprecate LegacyCommon.
extension SmartPortSelectorBridge: @retroactive DependencyKey {
    public static let liveValue = SmartPortSelectorBridge(select: { endpoint, connectionProtocol in
        @Dependency(\.propertiesManager) var propertiesManager
        let resolver = AvailabilityCheckerResolverImplementation(wireguardConfig: propertiesManager.wireguardConfig)
        let serverIP = ServerIp(endpoint: endpoint)

        return await withCheckedContinuation { continuation in
            switch connectionProtocol {
            case .smartProtocol:
                let smartProtocolImplementation = SmartProtocolImplementation(
                    availabilityCheckerResolver: resolver,
                    smartProtocolConfig: propertiesManager.smartProtocolConfig,
                    wireguardConfig: propertiesManager.wireguardConfig
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
    })
}
