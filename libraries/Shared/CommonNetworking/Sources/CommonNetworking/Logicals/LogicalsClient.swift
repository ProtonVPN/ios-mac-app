//
//  Created on 21/05/2024.
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
import Ergonomics

public struct LogicalsClient: Sendable {
    public var fetchLogicals: @Sendable (TruncatedIp?, String?) async throws -> [VPNServer]
}

extension LogicalsClient: DependencyKey {
    public static var liveValue: LogicalsClient {
        @Dependency(\.networking) var networking
        return LogicalsClient(
            fetchLogicals: { ip, countryCode in
                let request = LogicalsRequest(
                    ip: ip,
                    countryCodes: (countryCode.map { [$0] }) ?? [],
                    freeTier: false
                )
                let response: LogicalsResponse = try await networking.perform(request: request)
                return response.logicalServers.map { $0.vpnServer }
            }
        )
    }
}

extension DependencyValues {
    public var logicalsClient: LogicalsClient {
      get { self[LogicalsClient.self] }
      set { self[LogicalsClient.self] = newValue }
    }
}

extension LogicalDTO {
    var vpnServer: VPNServer {
        VPNServer(
            logical: Logical(
                id: id,
                name: name,
                domain: domain,
                load: load,
                entryCountryCode: entryCountry,
                exitCountryCode: exitCountry,
                tier: tier,
                score: score,
                status: status,
                feature: features,
                city: city,
                hostCountry: hostCountry,
                translatedCity: translatedCity,
                latitude: location.lat,
                longitude: location.long,
                gatewayName: gatewayName
            ),
            endpoints: servers.map {
                ServerEndpoint(
                    id: $0.id,
                    entryIp: $0.entryIp,
                    exitIp: $0.exitIp,
                    domain: $0.domain,
                    status: $0.status,
                    label: $0.label,
                    x25519PublicKey: $0.x25519PublicKey,
                    protocolEntries: $0.protocolEntries
                )
            }
        )
    }
}
