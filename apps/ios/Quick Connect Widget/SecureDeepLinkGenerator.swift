//
//  Created on 26.09.23.
//
//  Copyright (c) 2023 Proton AG
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
import KeychainAccess
import VPNCrypto
import VPNAppCore

class SecureDeepLinkGenerator {
    private typealias Env = SecureDeepLinkGeneratorEnvironment
    public typealias Key = CryptoService.Key

    let cryptoService = CryptoService()

    private func setPublicKey(_ key: Key) throws {
        try Env.appKeychain.setKey(key, Env.publicDataKey)
    }

    private func setPrivateKey(_ key: Key) throws {
        try Env.widgetKeychain.setKey(key, Env.privateDataKey)
    }

    private func getPrivateKey() throws -> Key {
        try Env.widgetKeychain.getKey(key: Env.privateDataKey, keyClass: .privateKey)
    }

    private func missingPublicKey() -> Bool {
        do {
            _ = try Env.appKeychain.getKey(key: Env.publicDataKey, keyClass: .publicKey)
            return false
        } catch {
            return true
        }
    }

    private func ensureKeys() throws -> Key {
        if missingPublicKey(), let privateKey = try? getPrivateKey() {
            return privateKey
        }

        let key = try Key.random(attrs: [
            kSecAttrKeyType as String: CryptoConstants.widgetChallengeKeyType.stringValue,
            kSecAttrKeySizeInBits as String: CryptoConstants.widgetChallengeKeyWidth,
            kSecAttrCanSign as String: true,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Env.privateDataKey.data(using: .utf8)!
            ] as [String: Any]
        ])

        guard let publicKey = key.publicKey else {
            throw "Could not extract public key from \(key.rawValue)"
        }

        try setPublicKey(publicKey)
        try setPrivateKey(key)

        return key
    }

    func makeSecureQuery() throws -> [URLQueryItem] {
        var timestamp = Int(Date().timeIntervalSince1970)
        let challenge = withUnsafeBytes(of: &timestamp) { Data($0) }
        let algorithm = CryptoConstants.widgetChallengeAlgorithm

        let key = try ensureKeys()

        let signature = try cryptoService.sign(challenge, with: key, algorithm: algorithm)

        return [
            URLQueryItem(name: "t", value: "\(timestamp)"),
            URLQueryItem(name: "s", value: signature.base64EncodedString()),
            URLQueryItem(name: "a", value: algorithm.stringValue),
        ]
    }
}

enum SecureDeepLinkGeneratorEnvironment {
    static var keychainAccessGroup: String = "\(appIdentifierPrefix)prt.ProtonVPN"

    static let privateDataKey = "ch.proton.vpn.widget.private_key"
    static let publicDataKey = "ch.proton.vpn.widget.public_key"

    static var appIdentifierPrefix: String {
        return Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    }

    static let widgetKeychain = Keychain(
        service: "ch.proton.vpn.widget",
        accessGroup: Self.keychainAccessGroup
    )

    static let appKeychain = Keychain(
        service: "ProtonVPN",
        accessGroup: Self.keychainAccessGroup
    )
}

fileprivate extension Keychain {
    typealias Key = CryptoService.Key

    func setKey(_ secKey: Key, _ key: String) throws {
        try set(secKey.data, key: key)
    }

    func getKey(key: String, keyClass: CryptoService.KeyClass) throws -> Key {
        guard let data = try getData(key) else {
            throw "Couldn't find key data"
        }

        return try Key(
            data: data,
            keyType: CryptoConstants.widgetChallengeKeyType,
            keyClass: keyClass,
            keySize: CryptoConstants.widgetChallengeKeyWidth
        )
    }
}
