//
//  Created on 04/06/2024.
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
import class GoLibs.Ed25519KeyPair
import ConnectionFoundations

extension PublicKey {
    package init(keyPair: Ed25519KeyPair) throws {
        var error: NSError?
        let derRepresentation = keyPair.publicKeyPKIXPem(&error)
        if let error {
            throw error
        }
        guard let publicKeyBytes = keyPair.publicKeyBytes() else {
            throw GoLibsCryptoError.missingData(nil)
        }
        self.init(
            rawRepresentation: ([UInt8])(publicKeyBytes),
            derRepresentation: derRepresentation
        )
    }
}

extension PrivateKey {
    package init(keyPair: Ed25519KeyPair) throws {
        guard let privateKeyBytes = keyPair.privateKeyBytes() else {
            throw GoLibsCryptoError.missingData(nil)
        }
        self.init(
            rawRepresentation: ([UInt8])(privateKeyBytes),
            derRepresentation: keyPair.privateKeyPKIXPem(),
            base64X25519Representation: keyPair.toX25519Base64()
        )
    }
}
