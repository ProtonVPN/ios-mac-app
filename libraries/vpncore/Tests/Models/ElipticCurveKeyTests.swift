//
//  ElipticCurveKeyTests.swift
//  vpncore - Created on 19.04.2021.
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
import XCTest

final class ElipticCurveKeyTests: XCTestCase {
    private let secretKey = PrivateKey(hex: "9d:68:0d:f3:05:ff:5b:10:db:5b:a0:dc:cb:6c:47:88:12:fd:f4:8a:ad:08:e9:96:d1:9a:28:f3:b3:2e:b2:56")
    private let publicKey = PublicKey(hex: "4b:90:a4:72:8e:94:7a:ea:ad:8c:2a:e5:f9:f6:cf:d5:af:75:1b:7d:9d:c8:e8:16:13:e4:61:ed:f6:64:8c:89")

    func testKeysGeneration() {
        let keys = VpnKeys()
        XCTAssertEqual(keys.publicKey.rawRepresentation.count, 32)
        XCTAssertFalse(keys.publicKey.derRepresentation.isEmpty)
        XCTAssertEqual(keys.privateKey.rawRepresentation.count, 32)
        XCTAssertFalse(keys.privateKey.derRepresentation.isEmpty)
    }

    func testSecretKeyDERformat() {
        XCTAssertEqual(
            """
            -----BEGIN PRIVATE KEY-----
            MC4CAQAwBQYDK2VwBCIEIJ1oDfMF/1sQ21ug3MtsR4gS/fSKrQjpltGaKPOzLrJW
            -----END PRIVATE KEY-----
            """
            , secretKey.derRepresentation.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
    }

    func testPublicKeyDERformat() {
        XCTAssertEqual(
            """
            -----BEGIN PUBLIC KEY-----
            MCowBQYDK2VwAyEAS5Ckco6UeuqtjCrl+fbP1a91G32dyOgWE+Rh7fZkjIk=
            -----END PUBLIC KEY-----
            """
            , publicKey.derRepresentation.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
    }

    func testConvertingSecretKeyToWireguardKey() {
        XCTAssertEqual("uDiY1T9gYZO90r2fC63At9T2CnV1X8/NfWaQ/v/gT2g=", secretKey.base64X25519Representation)
    }

    func testKeySerialization() {
        let keys = VpnKeys()
        let serialized = try! JSONEncoder().encode(keys)
        let decoded = try! JSONDecoder().decode(VpnKeys.self, from: serialized)
        XCTAssertEqual(keys.privateKey.rawRepresentation, decoded.privateKey.rawRepresentation)
        XCTAssertEqual(keys.privateKey.derRepresentation, decoded.privateKey.derRepresentation)
        XCTAssertEqual(keys.privateKey.base64X25519Representation, decoded.privateKey.base64X25519Representation)
        XCTAssertEqual(keys.publicKey.rawRepresentation, decoded.publicKey.rawRepresentation)
        XCTAssertEqual(keys.publicKey.derRepresentation, decoded.publicKey.derRepresentation)
    }
}
