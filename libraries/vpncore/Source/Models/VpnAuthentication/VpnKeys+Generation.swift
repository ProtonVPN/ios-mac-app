//
//  VpnKeys+Generation.swift
//  Core
//
//  Created by Igor Kulman on 21.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import WireguardCrypto

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
        let keyPair = Ed25519KeyPair()!
        privateKey = PrivateKey(keyPair: keyPair)
        publicKey = PublicKey(keyPair: keyPair)
    }
}
