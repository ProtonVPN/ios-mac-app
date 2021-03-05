//
//  IKEv2AvailabilityChecker.swift
//  vpncore - Created on 05.03.2021.
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

final class IKEv2AvailabilityChecker {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "IKEv2AvailabilityCheckerQueue", qos: .utility)
    private let timeout: TimeInterval = 3

    func checkAvailability(server: ServerModel, completion: @escaping (Bool) -> Void) {
        let host = NWEndpoint.Host(server.domain)
        let port = NWEndpoint.Port("500")!

        let task = DispatchWorkItem {
            PMLog.D("IKEv2 NOT available for \(server.domain)")
            completion(false)
        }

        let complete = { [weak self] (result: Bool) in
            PMLog.D("IKEv2\(result ? "" : " NOT") available for \(server.domain)")
            completion(result)
            task.cancel()
            self?.connection?.cancel()
            self?.connection = nil
        }

        PMLog.D("Checking IKEv2 availability for \(server.domain)")

        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            guard let self = self else {
                return
            }

            switch state {
            case .ready:
                let packet = self.createTestPacket()
                self.connection?.receiveMessage { (data, context, isComplete, error) in
                    complete(data != nil)
                }
                self.connection?.send(content: packet, completion: NWConnection.SendCompletion.contentProcessed(({ (error) in
                    if error != nil {
                        complete(false)
                    }
                })))
            case .failed:
                complete(false)
            case .preparing, .setup, .waiting, .cancelled:
                break
            }
        }

        queue.asyncAfter(deadline: .now() + timeout, execute: task)
        connection?.start(queue: queue)
    }

    private func createTestPacket() -> Data {
        var bytes: [UInt8] = []
        for _ in 0 ..< 8 {
            bytes.append(UInt8.random(in: 0..<255))
        }
        for _ in 0 ..< 8 {
            bytes.append(0)
        }
        bytes.append(0x21)
        bytes.append(0x20)
        bytes.append(0x22)
        bytes.append(0x08)
        for _ in 0 ..< 4 {
            bytes.append(0)
        }
        for _ in 0 ..< 4 {
            bytes.append(0)
        }

        return Data(bytes)
    }
}
