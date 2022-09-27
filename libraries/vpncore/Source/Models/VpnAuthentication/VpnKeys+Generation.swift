//
//  VpnKeys+Generation.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import Crypto_VPN
import VPNShared

extension PublicKey {
    init(keyPair: Ed25519KeyPair) {
        var error: NSError?
        rawRepresentation = ([UInt8])(keyPair.publicKeyBytes()!)
        derRepresentation = keyPair.publicKeyPKIXPem(&error)
    }
}

extension PrivateKey {
    init(keyPair: Ed25519KeyPair) {
        rawRepresentation = ([UInt8])(keyPair.privateKeyBytes()!)
        derRepresentation = keyPair.privateKeyPKIXPem()
        base64X25519Representation = keyPair.toX25519Base64()
    }
}

extension VpnKeys {
    init() {
        var error: NSError?
        let keyPair = Ed25519NewKeyPair(&error)!
        privateKey = PrivateKey(keyPair: keyPair)
        publicKey = PublicKey(keyPair: keyPair)
    }
}
