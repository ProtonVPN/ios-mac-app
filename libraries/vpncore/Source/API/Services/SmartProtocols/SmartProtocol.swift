//
//  SmartProtocol.swift
//  vpncore - Created on 08.03.2021.
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

typealias SmartProtocolCompletion = (VpnProtocol, [Int]) -> Void

protocol SmartProtocol {
    func determineBestProtocol(server: ServerModel, completion: @escaping SmartProtocolCompletion)
}

final class SmartProtocolImplementation: SmartProtocol {
    private enum SmartProtocolProtocol: Int {
        case ikev2
        case openVpnUdp
        case openVpnTcp

        var vpnProtocol: VpnProtocol {
            switch self {
            case .ikev2:
                return .ike
            case .openVpnUdp:
                return .openVpn(.udp)
            case .openVpnTcp:
                return .openVpn(.tcp)
            }
        }
    }

    private let checkers: [SmartProtocolProtocol: SmartProtocolAvailabilityChecker]
    private let queue: DispatchQueue

    init(config: OpenVpnConfig) {
        let queue = DispatchQueue(label: "SmartProtocolQueue", attributes: .concurrent)

        checkers = [
            .ikev2: IKEv2AvailabilityChecker(),
            .openVpnUdp: OpenVPNUDPAvailabilityChecker(config: config),
            .openVpnTcp: OpenVPNTCPAvailabilityChecker(config: config)
        ]
        self.queue = queue
    }

    func determineBestProtocol(server: ServerModel, completion: @escaping SmartProtocolCompletion) {
        let group = DispatchGroup()
        var availablePorts: [SmartProtocolProtocol: [Int]] = [:]

        PMLog.D("Determining best protocol for \(server.domain)")

        for (proto, checker) in checkers {
            group.enter()
            checker.checkAvailability(server: server) { result in
                switch result {
                case .unavailable:
                    break
                case let .available(ports: ports):
                    availablePorts[proto] = ports
                }

                group.leave()
            }
        }

        group.notify(queue: queue) {
            let sorted = availablePorts.keys.sorted(by: { lhs, rhs in lhs.rawValue < rhs.rawValue })

            guard let best = sorted.first, let ports = availablePorts[best] else {
                PMLog.D("No best protocol determined, fallback to IKEv2")
                completion(VpnProtocol.ike, [])
                return
            }

            PMLog.D("Best protocol for \(server.domain) is \(best.vpnProtocol) with ports \(ports)")
            completion(best.vpnProtocol, ports)
        }
    }
}
