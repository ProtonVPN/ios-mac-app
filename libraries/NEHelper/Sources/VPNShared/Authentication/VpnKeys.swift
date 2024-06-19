//
//  VpnKeys.swift
//  vpncore - Created on 15.04.2021.
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

/**
 Ed25519 public key
 */
public struct PublicKey: Sendable, Codable, CustomStringConvertible, CustomDebugStringConvertible {

    // 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    // ASN.1 DER
    public let derRepresentation: String
    
    public init(rawRepresentation: [UInt8], derRepresentation: String) {
        self.rawRepresentation = rawRepresentation
        self.derRepresentation = derRepresentation
    }

    public var description: String {
    #if DEBUG
        return "PublicKey(fingerprint: '\(Data(rawRepresentation).fingerprint)', base64: '\(Data(rawRepresentation).base64EncodedString())')"
    #else
        return "PublicKey(fingerprint: '\(Data(rawRepresentation).fingerprint)')"
    #endif
    }

    public var debugDescription: String { description }
}

/**
 Ed25519 private key
 */
public struct PrivateKey: Sendable, Codable, CustomStringConvertible, CustomDebugStringConvertible {
    // 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    // ASN.1 DER
    public let derRepresentation: String

    // base64 encoded X25519 key
    public let base64X25519Representation: String
    
    public init(rawRepresentation: [UInt8], derRepresentation: String, base64X25519Representation: String) {
        self.rawRepresentation = rawRepresentation
        self.derRepresentation = derRepresentation
        self.base64X25519Representation = base64X25519Representation
    }

    public var description: String {
    #if DEBUG
        return "PrivateKey(fingerprint: '\(Data(rawRepresentation).fingerprint)')"
    #else
        return "PrivateKey(<redacted>)"
    #endif
    }

    public var debugDescription: String  { description }
}

/**
 Ed25519 key pair
 */
public struct VpnKeys: Sendable, Codable {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey
    
    public init(privateKey: PrivateKey, publicKey: PublicKey) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }
}
