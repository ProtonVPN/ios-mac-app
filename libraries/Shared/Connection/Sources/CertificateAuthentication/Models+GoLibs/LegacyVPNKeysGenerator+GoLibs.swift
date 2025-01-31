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

import CoreConnection

// We are reusing `VPNShared.VpnAuthenticationKeychain` for now. This requires the key generator dependency to be
// implemented in another package, since we do not want `VPNShared` to depend on GoLibs.
// These implementations are copied over from LegacyCommon and should be superceded by the new implementations defined
// in this package when we are ready to refactor VpnAuthenticationKeychain.

extension VPNShared.VPNKeysGenerator: DependencyKey {
    private static var commonImplementation: VPNShared.VPNKeysGenerator {
        return .init(generateKeys: {
            var error: NSError?
            let keyPair = Ed25519NewKeyPair(&error)!
            let privateKey = PrivateKey(keyPair: keyPair)
            let publicKey = PublicKey(keyPair: keyPair)
            return VpnKeys(privateKey: privateKey, publicKey: publicKey)
        })
    }

    public static let testValue: VPNShared.VPNKeysGenerator = commonImplementation
    public static let liveValue: VPNShared.VPNKeysGenerator = {
        #if os(macOS)
        return commonImplementation
        #else
        return .init {
            let keys = try VPNKeysGenerator.liveValue.generateKeys() // Leveraging this generator with better error handling
            return VpnKeys(fromConnectionPackageKeys: keys)
        }
        #endif
    }()
}

extension VpnKeys {
    init(fromConnectionPackageKeys keys: VPNKeys) {
        self.init(
            privateKey: .init(
                rawRepresentation: keys.privateKey.rawRepresentation,
                derRepresentation: keys.privateKey.derRepresentation,
                base64X25519Representation: keys.privateKey.base64X25519Representation
            ),
            publicKey: .init(
                rawRepresentation: keys.publicKey.rawRepresentation,
                derRepresentation: keys.publicKey.derRepresentation
            )
        )
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
