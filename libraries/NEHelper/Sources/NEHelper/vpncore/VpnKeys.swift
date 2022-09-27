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

import Foundation

/**
 Ed25519 public key
 */
public struct PublicKey: Codable {
    // 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    // ASN.1 DER
    public let  derRepresentation: String      
}

/**
 Ed25519 private key
 */
public struct PrivateKey: Codable {
    // 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    // ASN.1 DER
    public let derRepresentation: String

    // base64 encoded X25519 key
    public let base64X25519Representation: String     
}

/**
 Ed25519 key pair
 */
public struct VpnKeys: Codable {
    let privateKey: PrivateKey
    let publicKey: PublicKey
}
