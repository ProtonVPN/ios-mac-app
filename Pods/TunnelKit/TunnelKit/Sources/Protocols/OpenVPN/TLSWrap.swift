//
//  TLSWrap.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/11/18.
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

extension OpenVPN {

    /// Holds parameters for TLS wrapping.
    public class TLSWrap: Codable {

        /// The wrapping strategy.
        public enum Strategy: String, Codable {
            
            /// Authenticates payload (--tls-auth).
            case auth

            /// Encrypts payload (--tls-crypt).
            case crypt
        }

        /// The wrapping strategy.
        public let strategy: Strategy
        
        /// The static encryption key.
        public let key: StaticKey
        
        /// :nodoc:
        public init(strategy: Strategy, key: StaticKey) {
            self.strategy = strategy
            self.key = key
        }

        /// :nodoc:
        public static func deserialized(_ data: Data) throws -> TLSWrap {
            return try JSONDecoder().decode(TLSWrap.self, from: data)
        }
        
        /// :nodoc:
        public func serialized() -> Data? {
            return try? JSONEncoder().encode(self)
        }
    }
}
