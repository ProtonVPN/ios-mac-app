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

final class IKEv2AvailabilityChecker: SmartProtocolAvailabilityChecker {
    var connections: [String: NWConnection] = [:]
    let queue: DispatchQueue
    var protocolName: String {
        return "IKEv2"
    }
    let port: Int

    init(port: Int = 500) {
        self.queue = DispatchQueue(label: "IKEv2AvailabilityCheckerQueue", attributes: .concurrent)
        self.port = port
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: [port], parameters: .udp, completion: completion)
    }

    func createTestPacket() -> Data {
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
