//
//  StaticKey.swift
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
import __TunnelKitCore

extension OpenVPN {

    /// Represents an OpenVPN static key file (as generated with --genkey)
    public class StaticKey: Codable {
        enum CodingKeys: CodingKey {
            case data
            
            case dir
        }

        /// The key-direction field, usually 0 on servers and 1 on clients.
        public enum Direction: Int, Codable {

            /// Conventional server direction (implicit for tls-crypt).
            case server = 0
            
            /// Conventional client direction (implicit for tls-crypt).
            case client = 1
        }
        
        private static let contentLength = 256 // 2048-bit
        
        private static let keyCount = 4
        
        private static let keyLength = StaticKey.contentLength / StaticKey.keyCount

        private static let fileHead = "-----BEGIN OpenVPN Static key V1-----"
        
        private static let fileFoot = "-----END OpenVPN Static key V1-----"
        
        private static let nonHexCharset = CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted
        
        private let secureData: ZeroingData

        let direction: Direction?
        
        /// Returns the encryption key.
        ///
        /// - Precondition: `direction` must be non-nil.
        /// - Seealso: `ConfigurationBuilder.tlsWrap`
        public var cipherEncryptKey: ZeroingData {
            guard let direction = direction else {
                preconditionFailure()
            }
            switch direction {
            case .server:
                return key(at: 0)
                
            case .client:
                return key(at: 2)
            }
        }

        /// Returns the decryption key.
        ///
        /// - Precondition: `direction` must be non-nil.
        /// - Seealso: `ConfigurationBuilder.tlsWrap`
        public var cipherDecryptKey: ZeroingData {
            guard let direction = direction else {
                preconditionFailure()
            }
            switch direction {
            case .server:
                return key(at: 2)
                
            case .client:
                return key(at: 0)
            }
        }
        
        /// Returns the HMAC sending key.
        ///
        /// - Seealso: `ConfigurationBuilder.tlsWrap`
        public var hmacSendKey: ZeroingData {
            guard let direction = direction else {
                return key(at: 1)
            }
            switch direction {
            case .server:
                return key(at: 1)
                
            case .client:
                return key(at: 3)
            }
        }
        
        /// Returns the HMAC receiving key.
        ///
        /// - Seealso: `ConfigurationBuilder.tlsWrap`
        public var hmacReceiveKey: ZeroingData {
            guard let direction = direction else {
                return key(at: 1)
            }
            switch direction {
            case .server:
                return key(at: 3)
                
            case .client:
                return key(at: 1)
            }
        }
        
        /**
         Initializes with data and direction.
         
         - Parameter data: The key data.
         - Parameter direction: The key direction, or bidirectional if nil. For tls-crypt behavior, must not be nil.
         */
        public init(data: Data, direction: Direction?) {
            precondition(data.count == StaticKey.contentLength)
            secureData = Z(data)
            self.direction = direction
        }
        
        /**
         Initializes with file content and direction.
         
         - Parameter file: The text file containing the key.
         - Parameter direction: The key direction, or bidirectional if nil.
         */
        public convenience init?(file: String, direction: Direction?) {
            let lines = file.split(separator: "\n")
            self.init(lines: lines, direction: direction)
        }
        
        /// :nodoc:
        public convenience init?(lines: [Substring], direction: Direction?) {
            var isHead = true
            var hexLines: [Substring] = []

            for l in lines {
                if isHead {
                    guard !l.hasPrefix("#") else {
                        continue
                    }
                    guard l == StaticKey.fileHead else {
                        return nil
                    }
                    isHead = false
                    continue
                }
                guard let first = l.first else {
                    return nil
                }
                if first == "-" {
                    guard l == StaticKey.fileFoot else {
                        return nil
                    }
                    break
                }
                hexLines.append(l)
            }

            let hex = String(hexLines.joined())
            guard hex.count == 2 * StaticKey.contentLength else {
                return nil
            }
            if let _ = hex.rangeOfCharacter(from: StaticKey.nonHexCharset) {
                return nil
            }
            let data = Data(hex: hex)
            
            self.init(data: data, direction: direction)
        }
        
        /**
         Initializes as bidirectional.
         
         - Parameter biData: The key data.
         */
        public convenience init(biData data: Data) {
            self.init(data: data, direction: nil)
        }
        
        private func key(at: Int) -> ZeroingData {
            let size = secureData.count / StaticKey.keyCount // 64 bytes each
            assert(size == StaticKey.keyLength)
            return secureData.withOffset(at * size, count: size)
        }
        
        /// :nodoc:
        public static func deserialized(_ data: Data) throws -> StaticKey {
            return try JSONDecoder().decode(StaticKey.self, from: data)
        }
        
        /// :nodoc:
        public func serialized() -> Data? {
            return try? JSONEncoder().encode(self)
        }
        
        // MARK: Codable
        
        /// :nodoc:
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            secureData = Z(try container.decode(Data.self, forKey: .data))
            direction = try container.decodeIfPresent(Direction.self, forKey: .dir)
        }
        
        /// :nodoc:
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(secureData.toData(), forKey: .data)
            try container.encodeIfPresent(direction, forKey: .dir)
        }
    }
}
