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
    private let secretKey = SecretKey(rawRepresentation: [UInt8]("9d:68:0d:f3:05:ff:5b:10:db:5b:a0:dc:cb:6c:47:88:12:fd:f4:8a:ad:08:e9:96:d1:9a:28:f3:b3:2e:b2:56".dataFromHex()!))
    private let publicKey = PublicKey(rawRepresentation: [UInt8]("4b:90:a4:72:8e:94:7a:ea:ad:8c:2a:e5:f9:f6:cf:d5:af:75:1b:7d:9d:c8:e8:16:13:e4:61:ed:f6:64:8c:89".dataFromHex()!))

    func testKeysGeneration() {
        let keys = VpnKeys()
        XCTAssertEqual(keys.publicKey.rawRepresentation.count, 32)
        XCTAssertFalse(keys.publicKey.derRepresentation.isEmpty)
        XCTAssertEqual(keys.privateKey.rawRepresentation.count, 64)
        XCTAssertFalse(keys.privateKey.derRepresentation.isEmpty)
    }

    func testSecretKeyDERformat() {
        XCTAssertEqual(
            """
            -----BEGIN PRIVATE KEY-----
            MC4CAQAwBQYDK2VwBCIEIJ1oDfMF/1sQ21ug3MtsR4gS/fSKrQjpltGaKPOzLrJW
            -----END PRIVATE KEY-----
            """
            , secretKey.derRepresentation)
    }

    func testPublicKeyDERformat() {
        XCTAssertEqual(
            """
            -----BEGIN PUBLIC KEY-----
            MCowBQYDK2VwAyEAS5Ckco6UeuqtjCrl+fbP1a91G32dyOgWE+Rh7fZkjIk=
            -----END PUBLIC KEY-----
            """
            , publicKey.derRepresentation)
    }

    func testConvertingSecretKeyToWireguardKey() {
        let converted = secretKey.rawX25519Representation
        let base64 = Data(bytes: converted).base64EncodedString()
        XCTAssertEqual("uDiY1T9gYZO90r2fC63At9T2CnV1X8/NfWaQ/v/gT2g=", base64)
    }
}
