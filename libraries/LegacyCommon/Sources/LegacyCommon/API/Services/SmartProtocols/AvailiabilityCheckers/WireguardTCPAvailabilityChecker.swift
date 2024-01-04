//
//  Created on 2022-07-14.
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

class WireguardTCPAvailabilityChecker: SmartProtocolAvailabilityChecker {
    let transport: WireGuardTransport

    var vpnProtocol: VpnProtocol {
        .wireGuard(transport)
    }

    private let config: WireguardConfig
    
    var defaultPorts: [Int] {
        switch transport {
        case .udp: return config.defaultUdpPorts
        case .tcp: return config.defaultTcpPorts
        case .tls: return config.defaultTlsPorts
        }
    }

    init(config: WireguardConfig, transport: WireGuardTransport) {
        self.config = config
        self.transport = transport
    }
    
    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        let defaultPorts = config.defaultTcpPorts

        checkAvailability(server: server, ports: defaultPorts) { result in
            switch result {
            case let .available(ports: ports):
                completion(.available(ports: ports))
            case .unavailable:
                // In case no Wireguard ports respon we wait a bit and try again just to be sure
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.checkAvailability(server: server, ports: defaultPorts, completion: completion)
                }
            }
        }
    }
    
    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        completion(true) // FUTUREDO: Implement
    }
}
