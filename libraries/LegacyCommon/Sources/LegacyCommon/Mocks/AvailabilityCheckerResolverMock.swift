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

#if DEBUG
import Foundation

import Domain
import VPNShared

public class AvailabilityCheckerResolverFactoryMock: AvailabilityCheckerResolverFactory {
    public var mockResolver: AvailabilityCheckerResolverMock!
    public var checkers: [VpnProtocol: AvailabilityCheckerMock]

    public init(checkers: [VpnProtocol: AvailabilityCheckerMock]) {
        self.checkers = checkers
    }

    public func makeAvailabilityCheckerResolver(wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver {
        if mockResolver == nil {
            mockResolver = AvailabilityCheckerResolverMock(wireguardConfig: wireguardConfig, checkers: checkers)
        }
        return mockResolver
    }
}

public class AvailabilityCheckerResolverMock: AvailabilityCheckerResolver {
    public let wireguardConfig: WireguardConfig

    public var checkers: [VpnProtocol: AvailabilityCheckerMock]

    public init(wireguardConfig: WireguardConfig, checkers: [VpnProtocol: AvailabilityCheckerMock]) {
        self.wireguardConfig = wireguardConfig
        self.checkers = checkers
    }

    public func availabilityChecker(for vpnProtocol: VpnProtocol) -> SmartProtocolAvailabilityChecker {
        checkers[vpnProtocol]!
    }
}

public class AvailabilityCheckerMock: SmartProtocolAvailabilityChecker {
    public typealias AvailabilityCallback = ((ServerIp) -> SmartProtocolAvailabilityCheckerResult)
    public var availabilityCallback: AvailabilityCallback?
    public var pingCallback: ((ServerIp, Int) -> Bool)?

    public let vpnProtocol: VpnProtocol
    public let availablePorts: [Int]

    public var defaultPorts: [Int] {
        availablePorts
    }

    public init(vpnProtocol: VpnProtocol, availablePorts: [Int]) {
        self.vpnProtocol = vpnProtocol
        self.availablePorts = availablePorts
    }

    public func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        if let pingCallback = pingCallback {
            completion(pingCallback(server, port))
            return
        }

        completion(true)
    }

    public func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        if let availabilityCallback = availabilityCallback {
            completion(availabilityCallback(server))
            return
        }

        guard !availablePorts.isEmpty else {
            completion(.unavailable)
            return
        }

        completion(.available(ports: availablePorts))
    }
}
#endif
