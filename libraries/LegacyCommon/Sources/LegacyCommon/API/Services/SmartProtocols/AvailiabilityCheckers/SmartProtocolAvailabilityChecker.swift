//
//  SmartProtocolAvailabilityChecker.swift
//  vpncore - Created on 06.03.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

import GoLibs

import Domain
import VPNShared

public enum SmartProtocolAvailabilityCheckerResult {
    case unavailable
    case available(ports: [Int])
}

public typealias SmartProtocolAvailabilityCheckerCompletion = (SmartProtocolAvailabilityCheckerResult) -> Void

public protocol SmartProtocolAvailabilityChecker: AnyObject {
    var timeout: TimeInterval { get }
    var vpnProtocol: VpnProtocol { get }
    var defaultPorts: [Int] { get }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion)
    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void)
}

extension SmartProtocolAvailabilityChecker {
    public var protocolName: String {
        vpnProtocol.localizedString
    }

    public var timeout: TimeInterval {
        return 3
    }

    func checkAvailability(server: ServerIp, ports: [Int], completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        log.debug("Checking \(protocolName) availability for \(server)", category: .connectionConnect, event: .scan)

        // Ports can be overridden for a given protocol and server
        let ports = server.protocolEntries?.overridePorts(using: vpnProtocol) ?? ports

        DispatchQueue.global().async {
            let group = DispatchGroup()
            var availablePorts: [Int] = []
            let lockQueue = DispatchQueue(label: "ch.proton.availability_checker.\(self.protocolName)")

            for port in ports.shuffled() {
                group.enter()
                self.ping(protocolName: self.protocolName, server: server, port: port, timeout: self.timeout) { receivedResponse in
                    lockQueue.sync {
                        guard receivedResponse else {
                            return
                        }
                        availablePorts.append(port)
                    }
                    group.leave()
                }
            }

            // don't use group.notify here - the dispatch group in this block will be freed
            // when execution leaves this scope
            group.wait()
            completion(availablePorts.isEmpty ? .unavailable : .available(ports: availablePorts))
        }
    }

    /// Pings all the ports and returns on the first successful try.
    func getFirstToRespondPort(server: ServerIp, completion: @escaping (Int?) -> Void) {
        log.debug("Getting best port for \(server) on \(vpnProtocol.localizedString)", category: .connectionConnect, event: .scan)

        DispatchQueue.global().async { [unowned self] in
            let group = DispatchGroup()
            let lockQueue = DispatchQueue(label: "ch.proton.port_checker.\(self.protocolName)")
            var portAlreadyFound = false // Prevents several calls to completion closure

            let ports = server.protocolEntries?.overridePorts(using: vpnProtocol) ?? defaultPorts
            for port in ports.shuffled() {
                group.enter()
                self.ping(protocolName: self.protocolName, server: server, port: port, timeout: self.timeout) { success in
                    defer { group.leave() }

                    let go = lockQueue.sync { () -> Bool in
                        guard success && !portAlreadyFound else {
                            return false
                        }
                        portAlreadyFound = true
                        log.debug("First port to respond is \(port). Returning this port to be used on \(self.vpnProtocol.localizedString).", category: .connectionConnect, event: .scan)
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

protocol SharedLibraryUDPAvailabilityChecker: SmartProtocolAvailabilityChecker {}

extension SharedLibraryUDPAvailabilityChecker {
    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        guard let entryIp = server.entryIp(using: vpnProtocol) else {
            log.error("Cannot find a valid entry IP for \(vpnProtocol).", category: .connectionConnect, event: .scan)
            completion(false)
            return
        }

        log.debug("Checking \(protocolName) availability for \(entryIp) on port \(port)", category: .connectionConnect, event: .scan)

        guard let key = server.x25519PublicKey else {
            log.error("Cannot check \(protocolName) availability for \(entryIp) on port \(port) because of missing public key", category: .connectionConnect, event: .scan)
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSError?
            var ret: ObjCBool = false
            let result = VpnPingPingSyncWithError(entryIp, port, key, Int(timeout * 1000), &ret, &error)

            if let error = error {
                log.error("\(protocolName) NOT available for \(entryIp) on port \(port) (Error: \(error))", category: .connectionConnect, event: .scan)
                completion(false)
                return
            }

            log.debug("\(protocolName)\(result ? "" : " NOT") available for \(entryIp) on port \(port)", category: .connectionConnect, event: .scan)
            completion(result)
        }
    }
}
