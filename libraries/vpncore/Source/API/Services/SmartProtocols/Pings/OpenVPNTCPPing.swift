//
//  TcpSmartProtocolAvailabilityCheckerPing.swift
//  Core
//
//  Created by Igor Kulman on 03.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import CommonCrypto
import Foundation
import Network

final class OpenVPNTCPSmartProtocolPing: SmartProtocolPing {
    private var connections: [String: NWConnection] = [:]
    private let config: OpenVpnConfig

    init(config: OpenVpnConfig) {
        self.config = config
    }

    // swiftlint:disable function_body_length
    func ping(protocolName: String, server: ServerIp, port: Int, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let host = NWEndpoint.Host(server.entryIp)

        guard let port = NWEndpoint.Port("\(port)") else {
            PMLog.ET("Invalid port for \(protocolName) smart protocol check")
            completion(false)
            return
        }

        var completed = false
        let connectionId = UUID().uuidString

        let cleanup = { [weak self] in
            self?.connections[connectionId]?.cancel()
        }

        let task = DispatchWorkItem {
            guard !completed else {
                return
            }

            completed = true
            PMLog.D("\(protocolName) NOT available for \(server.entryIp) on port \(port) (timeout)")
            cleanup()
            completion(false)
        }

        let complete = { (result: Bool) in
            guard !completed else {
                return
            }

            completed = true
            PMLog.D("\(protocolName)\(result ? "" : " NOT") available for \(server.entryIp) on port \(port)")
            task.cancel()
            cleanup()
            completion(result)
        }

        PMLog.D("Checking \(protocolName) availability for \(server.entryIp) on port \(port)")

        let packet = createOpenVPNHandshake(config: config, includeLength: true)
        let connection = NWConnection(host: host, port: port, using: .tcp)
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            switch state {
            case .ready:
                connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { (data, context, isComplete, error) in
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

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: task)
        connections[connectionId] = connection
        connection.start(queue: .global())
    }
    // swiftlint:enable function_body_length

    private func createOpenVPNHandshake(config: OpenVpnConfig, includeLength: Bool) -> Data {
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
