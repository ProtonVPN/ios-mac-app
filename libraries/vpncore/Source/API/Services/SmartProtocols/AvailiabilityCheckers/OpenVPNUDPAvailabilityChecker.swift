//
//  OpenVPNUDPAvailabilityChecker.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

final class OpenVPNUDPAvailabilityChecker: SharedLibrarySmartProtocolAvailabilityChecker {
    var protocolName: String {
        return "OpenVPN UDP"
    }
    private let config: OpenVpnConfig

    init(config: OpenVpnConfig) {
        self.config = config
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: config.defaultUdpPorts, completion: completion)
    }
}
