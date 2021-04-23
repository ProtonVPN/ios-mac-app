//
//  VpnKeys.swift
//  vpncore - Created on 15.04.2021.
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
import WireguardSRP

/**
 Ed25519 public key
 */
public struct PublicKey {
    // 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    // base64 encoded raw key
    public let base64Representation: String

    // ASN.1 DER
    public let  derRepresentation: String

    init(keyPair: Ed25519KeyPair) {
        var error: NSError?
        rawRepresentation = ([UInt8])(keyPair.publicKeyBytes()!)
        base64Representation = keyPair.publicKeyPKIXBase64(&error)
        derRepresentation = keyPair.publicKeyPKIXPem(&error)
    }    
}

/**
 Ed25519 private key
 */
public struct PrivateKey {
    // 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    // base64 encoded raw key
    public let base64Representation: String

    // ASN.1 DER
    public let derRepresentation: String

    // 32 byte X25519 key
    public let rawX25519Representation: [UInt8]

    // base64 encoded X25519 key
    public let base64X25519Representation: String

    init(keyPair: Ed25519KeyPair) {
        rawRepresentation = ([UInt8])(keyPair.privateKeyBytes()!)
        base64Representation = keyPair.privateKeyPKIXBase64()
        derRepresentation = keyPair.privateKeyPKIXPem()
        rawX25519Representation = ([UInt8])(keyPair.toX25519()!)
        base64X25519Representation = keyPair.toX25519Base64()
    }    
}

/**
 Ed25519 key pair
 */
public struct VpnKeys {
    let privateKey: PrivateKey
    let publicKey: PublicKey

    enum CodingKeys: String, CodingKey {
        case privateKey
        case publicKey
    }

    public init() {
        let keyPair = Ed25519KeyPair()!
        privateKey = PrivateKey(keyPair: keyPair)
        publicKey = PublicKey(keyPair: keyPair)
    }
}    

extension VpnKeys: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let privateKeyData = try values.decode(Data.self, forKey: .privateKey)
        let publicKeyData = try values.decode(Data.self, forKey: .publicKey)
        let keyPair = Ed25519CreateKeyPair(privateKeyData, publicKeyData)!
        privateKey = PrivateKey(keyPair: keyPair)
        publicKey = PublicKey(keyPair: keyPair)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Data(bytes: (privateKey.rawRepresentation)), forKey: .privateKey)
        try container.encode(Data(bytes: (publicKey.rawRepresentation)), forKey: .publicKey)
    }
}
