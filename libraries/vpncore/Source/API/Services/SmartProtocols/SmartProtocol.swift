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
import VPNShared

typealias SmartProtocolCompletion = (VpnProtocol, [Int]) -> Void

protocol SmartProtocol {
    func determineBestProtocol(server: ServerIp, completion: @escaping SmartProtocolCompletion)
}

final class SmartProtocolImplementation: SmartProtocol {
    private let availabilityCheckerResolver: AvailabilityCheckerResolver
    private let checkers: [SmartProtocolProtocol: SmartProtocolAvailabilityChecker]
    private let fallback: (SmartProtocolProtocol, [Int])

    init(availabilityCheckerResolver: AvailabilityCheckerResolver,
         smartProtocolConfig: SmartProtocolConfig,
         openVpnConfig: OpenVpnConfig,
         wireguardConfig: WireguardConfig) {
        self.availabilityCheckerResolver = availabilityCheckerResolver

        var checkers: [SmartProtocolProtocol: SmartProtocolAvailabilityChecker] = [:]
        var fallbackCandidates: [(SmartProtocolProtocol, [Int])] = []

        if smartProtocolConfig.iKEv2 {
            log.debug("IKEv2 will be used for Smart Protocol checks", category: .connectionConnect, event: .scan)
            checkers[.ikev2] = availabilityCheckerResolver.availabilityChecker(for: .ike)

            fallbackCandidates.append((SmartProtocolProtocol.ikev2, DefaultConstants.ikeV2Ports))
        }

        if smartProtocolConfig.openVPN {
            log.debug("OpenVPN will be used for Smart Protocol checks", category: .connectionConnect, event: .scan)
            checkers[.openVpnUdp] = availabilityCheckerResolver.availabilityChecker(for: .openVpn(.udp))
            checkers[.openVpnTcp] = availabilityCheckerResolver.availabilityChecker(for: .openVpn(.tcp))

            fallbackCandidates.append((SmartProtocolProtocol.openVpnUdp, openVpnConfig.defaultUdpPorts))
            fallbackCandidates.append((SmartProtocolProtocol.openVpnTcp, openVpnConfig.defaultTcpPorts))
        }

        if smartProtocolConfig.wireGuard {
            log.debug("Wireguard will be used for Smart Protocol checks", category: .connectionConnect, event: .scan)
            checkers[.wireguardUdp] = availabilityCheckerResolver.availabilityChecker(for: .wireGuard(.udp))
        }

        if smartProtocolConfig.wireGuardTcp {
            log.debug("Wireguard TCP will be used for Smart Protocol checks", category: .connectionConnect, event: .scan)

            checkers[.wireguardTcp] = availabilityCheckerResolver.availabilityChecker(for: .wireGuard(.tcp))
        }

        if smartProtocolConfig.wireGuardTls {
            log.debug("Wireguard TLS will be used for Smart Protocol checks", category: .connectionConnect, event: .scan)

            checkers[.wireguardTls] = availabilityCheckerResolver.availabilityChecker(for: .wireGuard(.tls))
        }

        if let fallback = fallbackCandidates.min(by: { lhs, rhs in lhs.0.priority < rhs.0.priority }) {
            self.fallback = fallback
        } else {
            #if os(iOS)
            self.fallback = (SmartProtocolProtocol.openVpnUdp, openVpnConfig.defaultUdpPorts)
            #else
            self.fallback = (SmartProtocolProtocol.ikev2, DefaultConstants.ikeV2Ports)
            #endif
        }

        self.checkers = checkers
    }

    func determineBestProtocol(server: ServerIp, completion: @escaping SmartProtocolCompletion) {
        guard !checkers.isEmpty else {
            log.error("Client config received from backend has all the VPN protocols disabled for Smart Protocol, fallback to \(fallback.0.vpnProtocol)", category: .connectionConnect, event: .scan)
            completion(fallback.0.vpnProtocol, fallback.1)
            return
        }

        let group = DispatchGroup()
        let lockQueue = DispatchQueue(label: "SmartProtocolQueue")
        var availablePorts: [SmartProtocolProtocol: [Int]] = [:]

        log.debug("Determining best protocol for \(server)", category: .connectionConnect, event: .scan)

        for (proto, checker) in checkers where server.supports(vpnProtocol: proto.vpnProtocol) {
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
                log.debug("No best protocol determined, fallback to \(fallback.0.vpnProtocol)", category: .connectionConnect, event: .scan)
                completion(fallback.0.vpnProtocol, fallback.1)
                return
            }

            log.debug("Best protocol for \(server.entryIp) is \(best.vpnProtocol) with ports \(ports)", category: .connectionConnect, event: .scan)
            completion(best.vpnProtocol, ports)
        }
    }
}
