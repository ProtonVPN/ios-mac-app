//
//  Created on 2022-10-19.
//
//  Copyright (c) 2022 Proton AG
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
import Dependencies
import GoLibs
import VPNShared

extension PublicKey {
    init(keyPair: Ed25519KeyPair) {
        var error: NSError?
        self.init(rawRepresentation: ([UInt8])(keyPair.publicKeyBytes()!),
                  derRepresentation: keyPair.publicKeyPKIXPem(&error))
    }
}

extension PrivateKey {
    init(keyPair: Ed25519KeyPair) {
        self.init(rawRepresentation: ([UInt8])(keyPair.privateKeyBytes()!),
                  derRepresentation: keyPair.privateKeyPKIXPem(),
                  base64X25519Representation: keyPair.toX25519Base64())
    }
}

extension VPNKeysGenerator: DependencyKey {
    public static var liveValue: VPNShared.VPNKeysGenerator {
        return .init(generateKeys: {
            var error: NSError?
            let keyPair = Ed25519NewKeyPair(&error)!
            let privateKey = PrivateKey(keyPair: keyPair)
            let publicKey = PublicKey(keyPair: keyPair)
            return VpnKeys(privateKey: privateKey, publicKey: publicKey)
        })
    }
}
