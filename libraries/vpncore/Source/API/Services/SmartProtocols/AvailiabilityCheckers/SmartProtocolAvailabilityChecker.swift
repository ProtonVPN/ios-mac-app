//
//  SmartProtocolAvailabilityChecker.swift
//  vpncore - Created on 06.03.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

enum SmartProtocolAvailabilityCheckerResult {
    case unavailable
    case available(ports: [Int])
}

typealias SmartProtocolAvailabilityCheckerCompletion = (SmartProtocolAvailabilityCheckerResult) -> Void

protocol SmartProtocolAvailabilityChecker: AnyObject {
    var lockQueue: DispatchQueue { get }
    var timeout: TimeInterval { get }
    var protocolName: String { get }
    var ping: SmartProtocolPing { get }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion)
}

extension SmartProtocolAvailabilityChecker {
    var timeout: TimeInterval {
        return 3
    }

    func checkAvailability(server: ServerIp, ports: [Int], completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        let group = DispatchGroup()
        var availablePorts: [Int] = []

        PMLog.D("Checking \(protocolName) availability for \(server.entryIp)")

        for port in ports {
            group.enter()
            ping.ping(protocolName: protocolName, server: server, port: port, timeout: timeout) { [weak self] result in
                guard let self = self else {
                    group.leave()
                    return
                }

                self.lockQueue.async {
                    if result {
                        availablePorts.append(port)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .global()) {
            completion(availablePorts.isEmpty ? .unavailable : .available(ports: availablePorts))
        }
    }
}
