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

final class WireguardAvailabilityChecker {
    private let config: WireguardConfig

    init(config: WireguardConfig) {
        self.config = config
    }
    
    /// Pings all the ports and returns on the first successfull try.
    func getFirtToRespondPort(server: ServerIp, completion: @escaping (Int?) -> Void) {
        PMLog.D("Getting best port for \(server.entryIp) on Wireguard")
        
        let group = DispatchGroup()
        let lockQueue = DispatchQueue(label: "\(protocolName)PortCheckerQueue")
        var portAlreadyFound = false // Prevents several calls to completion closure
        
        for port in config.defaultPorts.shuffled() {
            group.enter()
            ping(protocolName: protocolName, server: server, port: port, timeout: timeout) { success in
                lockQueue.async {
                    guard success && !portAlreadyFound else {
                        group.leave()
                        return
                    }
                    portAlreadyFound = true
                    PMLog.D("First port to respond is \(port). Returning this port to be used on Wireguard.")
                    completion(port)
                    group.leave()
                }
            }
        }
        group.notify(queue: .global()) {
            if !portAlreadyFound {
                PMLog.D("No working port found on Wireguard")
                completion(nil)
            }
        }
    }
}

extension WireguardAvailabilityChecker: SharedLibraryUDPAvailabilityChecker {
    
    var protocolName: String {
        return "Wireguard"
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: config.defaultPorts, completion: completion)
    }
}
