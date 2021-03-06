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
import Network

protocol SmartProtocolAvailabilityChecker: AnyObject {
    var connections: [String: NWConnection] { get set }
    var queue: DispatchQueue { get }
    var timeout: TimeInterval { get }
    var protocolName: String { get }

    func createTestPacket() -> Data
    func checkAvailability(server: ServerModel, completion: @escaping (Bool) -> Void) 
}

extension SmartProtocolAvailabilityChecker {
    var timeout: TimeInterval {
        return 3
    }

    func checkAvailability(server: ServerModel, ports: [Int], parameters: NWParameters, completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var results: [Bool] = []

        PMLog.D("Checking \(protocolName) availability for \(server.domain)")

        for port in ports {
            group.enter()
            checkAvailability(server: server, port: port, parameters: parameters) { result in
                results.append(result)
                group.leave()
            }
        }

        group.notify(queue: queue) {
            completion(!results.allSatisfy({ $0 == false }))
        }
    }

    // swiftlint:disable function_body_length
    func checkAvailability(server: ServerModel, port: Int, parameters: NWParameters, completion: @escaping (Bool) -> Void) {
        let protocolName = self.protocolName
        let host = NWEndpoint.Host(server.domain)

        guard let port = NWEndpoint.Port("\(port)") else {
            PMLog.ET("Invalid port for \(protocolName) smart protocol check")
            completion(false)
            return
        }

        var completed = false
        let connectionId = UUID().uuidString

        let cleanup = { [weak self] in
            self?.connections[connectionId]?.cancel()
            self?.connections.removeValue(forKey: connectionId)
        }

        let task = DispatchWorkItem {
            guard !completed else {
                return
            }

            completed = true
            PMLog.D("\(protocolName) NOT available for \(server.domain) on port \(port)")
            completion(false)
            cleanup()
        }

        let complete = { (result: Bool) in
            guard !completed else {
                return
            }

            completed = true
            PMLog.D("\(protocolName)\(result ? "" : " NOT") available for \(server.domain) on port \(port)")
            task.cancel()
            completion(result)
        }

        PMLog.D("Checking \(protocolName) availability for \(server.domain) on port \(port)")

        let packet = createTestPacket()
        let connection = NWConnection(host: host, port: port, using: parameters)
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            switch state {
            case .ready:
                connection.receive(minimumIncompleteLength: 1, maximumLength: Int.max) { (data, context, isComplete, error) in
                    complete(data != nil)
                }
                connection.send(content: packet, completion: NWConnection.SendCompletion.contentProcessed(({ (error) in
                    if error != nil {
                        complete(false)
                    }
                })))
            case .failed, .cancelled:
                complete(false)
            case .preparing, .setup, .waiting:
                break
            }
        }

        queue.asyncAfter(deadline: .now() + timeout, execute: task)
        connections[connectionId] = connection
        connection.start(queue: queue)
    }
    // swiftlint:enable function_body_length
}
