//
//  WireguardAvailabilityChecker.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

final class WireguardAvailabilityChecker: SmartProtocolAvailabilityChecker {
    let ping: SmartProtocolPing
    let lockQueue: DispatchQueue
    var protocolName: String {
        return "Wireguard"
    }
    let port: Int

    init(port: Int = 51820) {
        self.lockQueue = DispatchQueue(label: "WireguardAvailabilityCheckerQueue")
        self.port = port
        self.ping = SharedLibrarySmartProtocolPing()
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: [port], completion: completion)
    }
}
