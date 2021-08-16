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
    func determineBestProtocol(server: ServerIp, completion: @escaping SmartProtocolCompletion)
}

final class SmartProtocolImplementation: SmartProtocol {
    private let checkers: [SmartProtocolProtocol: SmartProtocolAvailabilityChecker]
    private let fallback: (SmartProtocolProtocol, [Int])

    init(smartProtocolConfig: SmartProtocolConfig, openVpnConfig: OpenVpnConfig, wireguardConfig: WireguardConfig) {
        var checkers: [SmartProtocolProtocol: SmartProtocolAvailabilityChecker] = [:]
        var fallbackCandidates: [(SmartProtocolProtocol, [Int])] = []

        if smartProtocolConfig.iKEv2 {
            PMLog.D("IKEv2 will be used for Smart Protocol checks")
            checkers[.ikev2] = IKEv2AvailabilityChecker()

            fallbackCandidates.append((SmartProtocolProtocol.ikev2, [500]))
        }

        if smartProtocolConfig.openVPN {
            PMLog.D("OpenVPN will be used for Smart Protocol checks")
            checkers[.openVpnUdp] = OpenVPNUDPAvailabilityChecker(config: openVpnConfig)
            checkers[.openVpnTcp] = OpenVPNTCPAvailabilityChecker(config: openVpnConfig)

            fallbackCandidates.append((SmartProtocolProtocol.openVpnUdp, openVpnConfig.defaultUdpPorts))
            fallbackCandidates.append((SmartProtocolProtocol.openVpnTcp, openVpnConfig.defaultTcpPorts))
        }

        if smartProtocolConfig.wireGuard {
            PMLog.D("Wireguard will be used for Smart Protocol checks")
            checkers[.wireguard] = WireguardAvailabilityChecker(config: wireguardConfig)

            fallbackCandidates.append((SmartProtocolProtocol.wireguard, wireguardConfig.defaultPorts))
        }

        if let fallback = fallbackCandidates.min(by: { lhs, rhs in lhs.0.priority < rhs.0.priority }) {
            self.fallback = fallback
        } else {
            #if os(iOS)
            self.fallback = (SmartProtocolProtocol.openVpnUdp, openVpnConfig.defaultUdpPorts)
            #else
            self.fallback = (SmartProtocolProtocol.ikev2, [500])
            #endif
        }

        self.checkers = checkers
    }

    func determineBestProtocol(server: ServerIp, completion: @escaping SmartProtocolCompletion) {
        guard !checkers.isEmpty else {
            PMLog.ET("Client config received from backend has all the VPN procols disabled for Smart Protocol, fallback to \(fallback.0.vpnProtocol)")
            completion(fallback.0.vpnProtocol, fallback.1)
            return
        }

        let group = DispatchGroup()
        let lockQueue = DispatchQueue(label: "SmartProtocolQueue")
        var availablePorts: [SmartProtocolProtocol: [Int]] = [:]

        PMLog.D("Determining best protocol for \(server.entryIp)")

        for (proto, checker) in checkers {
            group.enter()
            checker.checkAvailability(server: server) { result in
                lockQueue.async {
                    switch result {
                    case .unavailable:
                        break
                    case let .available(ports: ports):
                        availablePorts[proto] = ports
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .global()) { [fallback] in
            let sorted = availablePorts.keys.sorted(by: { lhs, rhs in lhs.priority < rhs.priority })

            guard let best = sorted.first, let ports = availablePorts[best], !ports.isEmpty else {
                PMLog.D("No best protocol determined, fallback to \(fallback.0.vpnProtocol)")
                completion(fallback.0.vpnProtocol, fallback.1)
                return
            }

            PMLog.D("Best protocol for \(server.entryIp) is \(best.vpnProtocol) with ports \(ports)")
            completion(best.vpnProtocol, ports)
        }
    }
}
