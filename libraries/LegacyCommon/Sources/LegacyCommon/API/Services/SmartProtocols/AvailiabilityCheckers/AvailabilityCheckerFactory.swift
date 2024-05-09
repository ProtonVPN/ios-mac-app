//
//  Created on 2022-06-27.
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

import Foundation

import Domain
import VPNShared

public protocol AvailabilityCheckerResolverFactory {
    func makeAvailabilityCheckerResolver(wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver
}

public protocol AvailabilityCheckerResolver {
    func availabilityChecker(for: VpnProtocol) -> SmartProtocolAvailabilityChecker
}

public class AvailabilityCheckerResolverImplementation: AvailabilityCheckerResolver {
    let wireguardConfig: WireguardConfig

    public init(wireguardConfig: WireguardConfig) {
        self.wireguardConfig = wireguardConfig
    }

    public func availabilityChecker(for vpnProtocol: VpnProtocol) -> SmartProtocolAvailabilityChecker {
        switch vpnProtocol {
        case .ike:
            return IKEv2AvailabilityChecker()
        case .openVpn:
            fatalError("OpenVPN has been deprecated")
        case .wireGuard(let transport):
            switch transport {
            case .udp:
                return WireguardUDPAvailabilityChecker(config: wireguardConfig)
            case .tcp:
                return WireguardTCPAvailabilityChecker(config: wireguardConfig, transport: .tcp)
            case .tls:
                return WireguardTCPAvailabilityChecker(config: wireguardConfig, transport: .tls)
            }
        }
    }
}
