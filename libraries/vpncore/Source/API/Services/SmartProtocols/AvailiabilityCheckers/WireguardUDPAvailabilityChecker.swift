//
//  WireguardAvailabilityChecker.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

final class WireguardUDPAvailabilityChecker {
    let vpnProtocol: VpnProtocol = .wireGuard(.udp)
    private let config: WireguardConfig

    init(config: WireguardConfig) {
        self.config = config
    }
}

extension WireguardUDPAvailabilityChecker: SharedLibraryUDPAvailabilityChecker {
    var defaultPorts: [Int] {
        config.defaultUdpPorts
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        let defaultPorts = config.defaultUdpPorts

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
}
