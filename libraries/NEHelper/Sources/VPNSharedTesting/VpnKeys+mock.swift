//
//  Created on 2022-10-06.
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
import VPNShared

public extension VpnKeys {
    static func mock(
        privateKey: Data = Data(),
        publicKey: Data = Data()
    ) -> VpnKeys {
        VpnKeys(
            privateKey: PrivateKey(
                rawRepresentation: [UInt8](privateKey),
                derRepresentation: String.random(8),
                base64X25519Representation: String.random(8)
            ),
            publicKey: PublicKey(
                rawRepresentation: [UInt8](publicKey),
                derRepresentation: String.random(8)
            )
        )
    }

    /// Initialiser with non-random contents is useful for TCA tests where we assert on equatable state
    static func mock(
        privateKey: String,
        publicKey: String
    ) -> VpnKeys {
        VpnKeys(
            privateKey: PrivateKey(
                rawRepresentation: [UInt8](privateKey.data(using: .utf8)!),
                derRepresentation: privateKey,
                base64X25519Representation: privateKey
            ),
            publicKey: PublicKey(
                rawRepresentation: [UInt8](publicKey.data(using: .utf8)!),
                derRepresentation: publicKey
            )
        )
    }
}

fileprivate extension String {
    static func random(_ length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< length).map { _ in chars.randomElement()! })
      }
}
