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
import Sodium

public struct PublicKey: Codable {
    let rawKey: [UInt8]
    var base64: String {
        let publicKeyData = "302A300506032B6570032100".data(using: .bytesHexLiteral)! + rawKey
        let publicKeyBase64 = publicKeyData.base64EncodedString()
        return "-----BEGIN PUBLIC KEY-----\n\(publicKeyBase64)\n-----END PUBLIC KEY-----"
    }
}

public struct PrivateKey: Codable {
    let rawKey: [UInt8]
    var base64: String {
        let privateKeyData = "302E020100300506032B657004220420".data(using: .bytesHexLiteral)! + rawKey
        let privateKeyBase64 = privateKeyData.base64EncodedString()
        return "-----BEGIN PRIVATE KEY-----\n\(privateKeyBase64)\n-----END PRIVATE KEY-----"
    }
}

struct VpnKeys: Codable {
    let privateKey: PrivateKey
    let publicKey: PublicKey

    init() {
        let sodium = Sodium()
        let keyPair = sodium.sign.keyPair()!
        privateKey = PrivateKey(rawKey: keyPair.secretKey)
        publicKey = PublicKey(rawKey: keyPair.publicKey)
    }
}    
