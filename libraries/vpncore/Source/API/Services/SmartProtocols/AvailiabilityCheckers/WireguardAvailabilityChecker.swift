//
//  WireguardAvailabilityChecker.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
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
