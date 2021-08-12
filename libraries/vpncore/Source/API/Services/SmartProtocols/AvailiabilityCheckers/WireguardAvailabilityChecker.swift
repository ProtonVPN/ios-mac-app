//
//  WireguardAvailabilityChecker.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

final class WireguardAvailabilityChecker: SharedLibraryUDPAvailabilityChecker {
    var protocolName: String {
        return "Wireguard"
    }
    private let config: WireguardConfig

    init(config: WireguardConfig) {
        self.config = config
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: config.defaultPorts, completion: completion)
    }
}
