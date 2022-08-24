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
@testable import vpncore

class AvailabilityCheckerResolverFactoryMock: AvailabilityCheckerResolverFactory {
    var mockResolver: AvailabilityCheckerResolverMock!
    var checkers: [VpnProtocol: AvailabilityCheckerMock]

    init(checkers: [VpnProtocol: AvailabilityCheckerMock]) {
        self.checkers = checkers
    }

    func makeAvailabilityCheckerResolver(openVpnConfig: OpenVpnConfig, wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver {
        if mockResolver == nil {
            mockResolver = AvailabilityCheckerResolverMock(openVpnConfig: openVpnConfig, wireguardConfig: wireguardConfig, checkers: checkers)
        }
        return mockResolver
    }
}

class AvailabilityCheckerResolverMock: AvailabilityCheckerResolver {
    let openVpnConfig: OpenVpnConfig
    let wireguardConfig: WireguardConfig

    var checkers: [VpnProtocol: AvailabilityCheckerMock]

    init(openVpnConfig: OpenVpnConfig, wireguardConfig: WireguardConfig, checkers: [VpnProtocol: AvailabilityCheckerMock]) {
        self.openVpnConfig = openVpnConfig
        self.wireguardConfig = wireguardConfig
        self.checkers = checkers
    }

    func availabilityChecker(for vpnProtocol: VpnProtocol) -> SmartProtocolAvailabilityChecker {
        checkers[vpnProtocol]!
    }
}

class AvailabilityCheckerMock: SmartProtocolAvailabilityChecker {
    var availabilityCallback: ((ServerIp) -> SmartProtocolAvailabilityCheckerResult)?
    var pingCallback: ((ServerIp, Int) -> Bool)?

    let vpnProtocol: VpnProtocol
    let availablePorts: [Int]

    var defaultPorts: [Int] {
        availablePorts
    }

    init(vpnProtocol: VpnProtocol, availablePorts: [Int]) {
        self.vpnProtocol = vpnProtocol
        self.availablePorts = availablePorts
    }

    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        if let pingCallback = pingCallback {
            completion(pingCallback(server, port))
            return
        }

        completion(true)
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
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
