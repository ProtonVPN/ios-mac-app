//
//  OpenVPNUDPAvailabilityChecker.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

final class OpenVPNUDPAvailabilityChecker: SmartProtocolAvailabilityChecker {
    let ping: SmartProtocolPing
    let lockQueue: DispatchQueue
    var protocolName: String {
        return "OpenVPN UDP"
    }
    private let config: OpenVpnConfig

    init(config: OpenVpnConfig) {
        self.lockQueue = DispatchQueue(label: "OpenVPNUDPAvailabilityCheckerQueue")
        self.config = config
        self.ping = SharedLibrarySmartProtocolPing()
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: config.defaultUdpPorts, completion: completion)
    }
}
