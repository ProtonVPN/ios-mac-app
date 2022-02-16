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
    func getFirstToRespondPort(server: ServerIp, completion: @escaping (Int?) -> Void) {
        log.debug("Getting best port for \(server.entryIp) on Wireguard", category: .connectionConnect, event: .scan)

        DispatchQueue.global().async { [weak self] in
            guard let `self` = self else { return }

            let group = DispatchGroup()
            let lockQueue = DispatchQueue(label: "ch.proton.port_checker.\(self.protocolName)")
            var portAlreadyFound = false // Prevents several calls to completion closure

            for port in self.config.defaultPorts.shuffled() {
                group.enter()
                self.ping(protocolName: self.protocolName, server: server, port: port, timeout: self.timeout) { success in
                    defer { group.leave() }

                    let go = lockQueue.sync { () -> Bool in
                        guard success && !portAlreadyFound else {
                            return false
                        }
                        portAlreadyFound = true
                        log.debug("First port to respond is \(port). Returning this port to be used on Wireguard.", category: .connectionConnect, event: .scan)
                        return true
                    }

                    guard go else { return }
                    completion(port)
                }
            }

            // don't use group.notify here - the dispatch group in this block will be freed
            // when execution leaves this scope
            group.wait()
            if !portAlreadyFound {
                log.error("No working port found on Wireguard", category: .connectionConnect, event: .scan)
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
