//
//  ControlChannelSerializer.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/10/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import SwiftyBeaver
import __TunnelKitCore
import __TunnelKitOpenVPN

private let log = SwiftyBeaver.self

protocol ControlChannelSerializer {
    func reset()
    
    func serialize(packet: ControlPacket) throws -> Data

    func deserialize(data: Data, start: Int, end: Int?) throws -> ControlPacket
}

extension OpenVPN.ControlChannel {
    class PlainSerializer: ControlChannelSerializer {
        func reset() {
        }
        
        func serialize(packet: ControlPacket) throws -> Data {
            return packet.serialized()
        }
        
        func deserialize(data packet: Data, start: Int, end: Int?) throws -> ControlPacket {
            var offset = start
            let end = end ?? packet.count
            
            guard end >= offset + PacketOpcodeLength else {
                throw OpenVPN.ControlChannelError("Missing opcode")
            }
            let codeValue = packet[offset] >> 3
            guard let code = PacketCode(rawValue: codeValue) else {
                throw OpenVPN.ControlChannelError("Unknown code: \(codeValue))")
            }
            let key = packet[offset] & 0b111
            offset += PacketOpcodeLength

            log.debug("Control: Try read packet with code \(code) and key \(key)")
            
            guard end >= offset + PacketSessionIdLength else {
                throw OpenVPN.ControlChannelError("Missing sessionId")
            }
            let sessionId = packet.subdata(offset: offset, count: PacketSessionIdLength)
            offset += PacketSessionIdLength

            guard end >= offset + 1 else {
                throw OpenVPN.ControlChannelError("Missing ackSize")
            }
            let ackSize = packet[offset]
            offset += 1

            var ackIds: [UInt32]?
            var ackRemoteSessionId: Data?
            if ackSize > 0 {
                guard end >= (offset + Int(ackSize) * PacketIdLength) else {
                    throw OpenVPN.ControlChannelError("Missing acks")
                }
                var ids: [UInt32] = []
                for _ in 0..<ackSize {
                    let id = packet.networkUInt32Value(from: offset)
                    ids.append(id)
                    offset += PacketIdLength
                }

                guard end >= offset + PacketSessionIdLength else {
                    throw OpenVPN.ControlChannelError("Missing remoteSessionId")
                }
                let remoteSessionId = packet.subdata(offset: offset, count: PacketSessionIdLength)
                offset += PacketSessionIdLength

                ackIds = ids
                ackRemoteSessionId = remoteSessionId
            }

            if code == .ackV1 {
                guard let ackIds = ackIds else {
                    throw OpenVPN.ControlChannelError("Ack packet without ids")
                }
                guard let ackRemoteSessionId = ackRemoteSessionId else {
                    throw OpenVPN.ControlChannelError("Ack packet without remoteSessionId")
                }
                return ControlPacket(key: key, sessionId: sessionId, ackIds: ackIds as [NSNumber], ackRemoteSessionId: ackRemoteSessionId)
            }

            guard end >= offset + PacketIdLength else {
                throw OpenVPN.ControlChannelError("Missing packetId")
            }
            let packetId = packet.networkUInt32Value(from: offset)
            offset += PacketIdLength

            var payload: Data?
            if offset < end {
                payload = packet.subdata(in: offset..<end)
            }

            let controlPacket = ControlPacket(code: code, key: key, sessionId: sessionId, packetId: packetId, payload: payload)
            if let ackIds = ackIds {
                controlPacket.ackIds = ackIds as [NSNumber]
                controlPacket.ackRemoteSessionId = ackRemoteSessionId
            }
            return controlPacket
        }
    }
}

extension OpenVPN.ControlChannel {
    class AuthSerializer: ControlChannelSerializer {
        private let encrypter: Encrypter
        
        private let decrypter: Decrypter
        
        private let prefixLength: Int
        
        private let hmacLength: Int
        
        private let authLength: Int
        
        private let preambleLength: Int
        
        private var currentReplayId: BidirectionalState<UInt32>
        
        private let timestamp: UInt32
        
        private let plain: PlainSerializer
        
        init(withKey key: OpenVPN.StaticKey, digest: OpenVPN.Digest) throws {
            let crypto = CryptoBox(cipherAlgorithm: nil, digestAlgorithm: digest.rawValue)
            try crypto.configure(
                withCipherEncKey: nil,
                cipherDecKey: nil,
                hmacEncKey: key.hmacSendKey,
                hmacDecKey: key.hmacReceiveKey
            )
            encrypter = crypto.encrypter()
            decrypter = crypto.decrypter()
            
            prefixLength = PacketOpcodeLength + PacketSessionIdLength
            hmacLength = crypto.digestLength()
            authLength = hmacLength + PacketReplayIdLength + PacketReplayTimestampLength
            preambleLength = prefixLength + authLength
            
            currentReplayId = BidirectionalState(withResetValue: 1)
            timestamp = UInt32(Date().timeIntervalSince1970)
            plain = PlainSerializer()
        }
        
        func reset() {
            currentReplayId.reset()
        }
        
        func serialize(packet: ControlPacket) throws -> Data {
            return try serialize(packet: packet, timestamp: timestamp)
        }
        
        func serialize(packet: ControlPacket, timestamp: UInt32) throws -> Data {
            let data = try packet.serialized(withAuthenticator: encrypter, replayId: currentReplayId.outbound, timestamp: timestamp)
            currentReplayId.outbound += 1
            return data
        }
        
        // XXX: start/end are ignored, parses whole packet
        func deserialize(data packet: Data, start: Int, end: Int?) throws -> ControlPacket {
            let end = packet.count
            
            // data starts with (prefix=(header + sessionId) + auth=(hmac + replayId))
            guard end >= preambleLength else {
                throw OpenVPN.ControlChannelError("Missing HMAC")
            }
            
            // needs a copy for swapping
            var authPacket = packet
            let authCount = authPacket.count
            try authPacket.withUnsafeMutableBytes {
                let ptr = $0.bytePointer
                PacketSwapCopy(ptr, packet, prefixLength, authLength)
                try decrypter.verifyBytes(ptr, length: authCount, flags: nil)
            }
            
            // TODO: validate replay packet id
            
            return try plain.deserialize(data: authPacket, start: authLength, end: nil)
        }
    }
}

extension OpenVPN.ControlChannel {
    class CryptSerializer: ControlChannelSerializer {
        private let encrypter: Encrypter
        
        private let decrypter: Decrypter
        
        private let headerLength: Int
        
        private var adLength: Int
        
        private let tagLength: Int
        
        private var currentReplayId: BidirectionalState<UInt32>
        
        private let timestamp: UInt32
        
        private let plain: PlainSerializer

        init(withKey key: OpenVPN.StaticKey) throws {
            let crypto = CryptoBox(cipherAlgorithm: "AES-256-CTR", digestAlgorithm: "SHA256")
            try crypto.configure(
                withCipherEncKey: key.cipherEncryptKey,
                cipherDecKey: key.cipherDecryptKey,
                hmacEncKey: key.hmacSendKey,
                hmacDecKey: key.hmacReceiveKey
            )
            encrypter = crypto.encrypter()
            decrypter = crypto.decrypter()
            
            headerLength = PacketOpcodeLength + PacketSessionIdLength
            adLength = headerLength + PacketReplayIdLength + PacketReplayTimestampLength
            tagLength = crypto.tagLength()

            currentReplayId = BidirectionalState(withResetValue: 1)
            timestamp = UInt32(Date().timeIntervalSince1970)
            plain = PlainSerializer()
        }
        
        func reset() {
            currentReplayId.reset()
        }
        
        func serialize(packet: ControlPacket) throws -> Data {
            return try serialize(packet: packet, timestamp: timestamp)
        }
        
        func serialize(packet: ControlPacket, timestamp: UInt32) throws -> Data {
            let data = try packet.serialized(with: encrypter, replayId: currentReplayId.outbound, timestamp: timestamp, adLength: adLength)
            currentReplayId.outbound += 1
            return data
        }
        
        // XXX: start/end are ignored, parses whole packet
        func deserialize(data packet: Data, start: Int, end: Int?) throws -> ControlPacket {
            let end = end ?? packet.count
            
            // data starts with (ad=(header + sessionId + replayId) + tag)
            guard end >= start + adLength + tagLength else {
                throw OpenVPN.ControlChannelError("Missing AD+TAG")
            }
            
            let encryptedCount = packet.count - adLength
            var decryptedPacket = Data(count: decrypter.encryptionCapacity(withLength: encryptedCount))
            var decryptedCount = 0
            try packet.withUnsafeBytes {
                let src = $0.bytePointer
                var flags = CryptoFlags(iv: nil, ivLength: 0, ad: src, adLength: adLength)
                try decryptedPacket.withUnsafeMutableBytes {
                    let dest = $0.bytePointer
                    try decrypter.decryptBytes(src + flags.adLength, length: encryptedCount, dest: dest + headerLength, destLength: &decryptedCount, flags: &flags)
                    memcpy(dest, src, headerLength)
                }
            }
            decryptedPacket.count = headerLength + decryptedCount
            
            // TODO: validate replay packet id
            
            return try plain.deserialize(data: decryptedPacket, start: 0, end: nil)
        }
    }
}
