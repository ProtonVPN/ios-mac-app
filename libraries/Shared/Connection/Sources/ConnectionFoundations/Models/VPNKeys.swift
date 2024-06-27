//
//  Created on 13/06/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// Ed25519 package key
public struct PublicKey: Equatable, Sendable, Codable {

    /// 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    /// ASN.1 DER
    public let derRepresentation: String

    public init(rawRepresentation: [UInt8], derRepresentation: String) {
        self.rawRepresentation = rawRepresentation
        self.derRepresentation = derRepresentation
    }
}

/// Ed25519 private key
public struct PrivateKey: Equatable, Sendable, Codable {
    /// 32 byte Ed25519 key
    public let rawRepresentation: [UInt8]

    /// ASN.1 DER
    public let derRepresentation: String

    /// base64 encoded X25519 key
    public let base64X25519Representation: String

    public init(rawRepresentation: [UInt8], derRepresentation: String, base64X25519Representation: String) {
        self.rawRepresentation = rawRepresentation
        self.derRepresentation = derRepresentation
        self.base64X25519Representation = base64X25519Representation
    }
}

/// Ed25519 key pair
public struct VPNKeys: Equatable, Sendable, Codable {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey

    public init(privateKey: PrivateKey, publicKey: PublicKey) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }
}
