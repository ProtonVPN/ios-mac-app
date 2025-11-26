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

import CommonNetworking
import Domain
import Foundation
import VPNShared

public protocol AvailabilityCheckerResolverFactory {
    func makeAvailabilityCheckerResolver(wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver
}

public protocol AvailabilityCheckerResolver {
    func availabilityChecker(for: VpnProtocol) -> SmartProtocolAvailabilityChecker
}

public final class AvailabilityCheckerResolverImplementation: AvailabilityCheckerResolver, Sendable {
    let wireguardConfig: WireguardConfig

    public init(wireguardConfig: WireguardConfig) {
        self.wireguardConfig = wireguardConfig
    }

    public func availabilityChecker(for vpnProtocol: VpnProtocol) -> SmartProtocolAvailabilityChecker {
        switch vpnProtocol {
        case .ike:
            IKEv2AvailabilityChecker()
        case .openVpn:
            fatalError("OpenVPN has been deprecated")
        case let .wireGuard(transport):
            switch transport {
            case .udp:
                WireguardUDPAvailabilityChecker(config: wireguardConfig)
            case .tcp:
                WireguardTCPAvailabilityChecker(config: wireguardConfig, transport: .tcp)
            case .tls:
                WireguardTCPAvailabilityChecker(config: wireguardConfig, transport: .tls)
            }
        }
    }
}
