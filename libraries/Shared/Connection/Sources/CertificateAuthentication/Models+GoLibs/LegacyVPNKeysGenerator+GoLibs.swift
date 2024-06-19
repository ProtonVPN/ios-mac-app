//
//  Created on 19/06/2024.
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
import Dependencies

import func GoLibs.Ed25519NewKeyPair
import class GoLibs.Ed25519KeyPair
import struct VPNShared.VPNKeysGenerator
import struct VPNShared.VpnKeys
import struct VPNShared.PrivateKey
import struct VPNShared.PublicKey

// We are reusing `VPNShared.VpnAuthenticationKeychain` for now. This requires the key generator dependency to be
// implemented in another package, since we do not want `VPNShared` to depend on GoLibs.
// These implementations are copied over from LegacyCommon and should be superceded by the new implementations defined
// in this package when we are ready to refactor VpnAuthenticationKeychain.

extension VPNShared.VPNKeysGenerator: DependencyKey {
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

extension VPNShared.PublicKey {
    init(keyPair: Ed25519KeyPair) {
        var error: NSError?
        self.init(
            rawRepresentation: ([UInt8])(keyPair.publicKeyBytes()!),
            derRepresentation: keyPair.publicKeyPKIXPem(&error)
        )
    }
}

extension VPNShared.PrivateKey {
    init(keyPair: Ed25519KeyPair) {
        self.init(
            rawRepresentation: ([UInt8])(keyPair.privateKeyBytes()!),
            derRepresentation: keyPair.privateKeyPKIXPem(),
            base64X25519Representation: keyPair.toX25519Base64()
        )
    }
}
