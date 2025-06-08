//
//  Created on 25/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Connection
import Dependencies
import Domain

extension SmartPortSelectorBridge: @retroactive DependencyKey {
    public static let liveValue: SmartPortSelectorBridge = .init(
        select: { endpoint, _ in
            let defaultTVOSProtocol: VpnProtocol = .wireGuard(.udp)
            @Dependency(\.connectionConfiguration) var configurationProvider
            let defaultPorts = configurationProvider.configuration().wireguardConfig.defaultPorts(for: .udp)
            let ports = endpoint.overridePorts(using: defaultTVOSProtocol) ?? defaultPorts

            return .init(chosenProtocol: defaultTVOSProtocol, ports: ports)
        }
    )
}
