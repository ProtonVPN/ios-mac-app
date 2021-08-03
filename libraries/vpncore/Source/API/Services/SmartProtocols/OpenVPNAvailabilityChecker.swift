//
//  OpenVPNAvailabilityChecker.swift
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

import CommonCrypto
import Foundation
import Network

final class OpenVPNTCPAvailabilityChecker: OpenVPNAvailabilityChecker, SmartProtocolAvailabilityChecker {
    var connections: [String: NWConnection] = [:]
    let lockQueue: DispatchQueue
    var protocolName: String {
        return "OpenVPN TCP"
    }
    let config: OpenVpnConfig

    init(config: OpenVpnConfig) {
        self.lockQueue = DispatchQueue(label: "OpenVPNTCPAvailabilityCheckerQueue")
        self.config = config
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: config.defaultTcpPorts, parameters: .tcp, completion: completion)
    }

    func createTestPacket() -> Data {
        return createOpenVPNHandshake(config: config, includeLength: true)
    }
}

final class OpenVPNUDPAvailabilityChecker: OpenVPNAvailabilityChecker, SmartProtocolAvailabilityChecker {
    var connections: [String: NWConnection] = [:]
    let lockQueue: DispatchQueue
    var protocolName: String {
        return "OpenVPN UDP"
    }
    let config: OpenVpnConfig

    init(config: OpenVpnConfig) {
        self.lockQueue = DispatchQueue(label: "OpenVPNUDPAvailabilityCheckerQueue")
        self.config = config
    }

    func checkAvailability(server: ServerIp, completion: @escaping SmartProtocolAvailabilityCheckerCompletion) {
        checkAvailability(server: server, ports: config.defaultUdpPorts, parameters: .udp, completion: completion)
    }

    func createTestPacket() -> Data {
        return createOpenVPNHandshake(config: config, includeLength: false)
    }
}

protocol OpenVPNAvailabilityChecker {
    func createOpenVPNHandshake(config: OpenVpnConfig, includeLength: Bool) -> Data
}

extension OpenVPNAvailabilityChecker {
    func createOpenVPNHandshake(config: OpenVpnConfig, includeLength: Bool) -> Data {
        let key = stringToBytes(string: config.staticKey)
        let bytes = getBytes(key: key, includeLength: includeLength)
        return Data(bytes)
    }

    private func stringToBytes(string: String) -> [UInt8] {
        let length = string.count
        if length & 1 != 0 {
            return []
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(length / 2)
        var index = string.startIndex
        for _ in 0..<length / 2 {
            let nextIndex = string.index(index, offsetBy: 2)
            if let b = UInt8(string[index..<nextIndex], radix: 16) {
                bytes.append(b)
            } else {
                return []
            }
            index = nextIndex
        }
        return Array(bytes.suffix(64))
    }

    private func getBytes(key: [UInt8], includeLength: Bool) -> [UInt8] {
        let sid = randomBytes(length: 8)
        let ts = Int(Date().timeIntervalSince1970)

        var packet: [UInt8] = []
        packet.append(contentsOf: [0, 0, 0, 1])
        packet.append(contentsOf: byteArray(from: ts).suffix(4))
        packet.append(7 << 3)
        for s in sid {
            packet.append(s)
        }
        packet.append(contentsOf: [0, 0, 0, 0, 0])

        let hash = digest(key: key, input: packet)

        var result: [UInt8] = []
        result.append(7 << 3)
        for s in sid {
            result.append(s)
        }
        for hs in hash {
            result.append(hs)
        }
        result.append(contentsOf: [0, 0, 0, 1])
        result.append(contentsOf: byteArray(from: ts).suffix(4))
        result.append(contentsOf: [0, 0, 0, 0, 0])

        if !includeLength {
            return result
        }

        let length = byteArray(from: result.count).suffix(2)
        return length + result
    }

    private func randomBytes(length: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        for _ in 0 ..< length {
            bytes.append(UInt8.random(in: 0..<255))
        }
        return bytes
    }

    private func digest(key: [UInt8], input: [UInt8]) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA512), key, key.count, input, input.count, &digest)
        return digest
    }

    private func byteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }
}
