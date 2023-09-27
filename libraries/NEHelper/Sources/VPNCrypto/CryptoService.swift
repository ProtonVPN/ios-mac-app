//
//  Created on 28.09.23.
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
import Dependencies
import Ergonomics

internal enum CryptoServiceEnvironment {
    static var secKeyCopyData = SecKeyCopyExternalRepresentation
    static var secKeyCreateWithData = SecKeyCreateWithData
    static var secKeyCreateRandom = SecKeyCreateRandomKey
    static var secCreateSignature = SecKeyCreateSignature
    static var secKeyCopyPublicKey = SecKeyCopyPublicKey
    static var secKeyVerifySignature = SecKeyVerifySignature
}

public class CryptoService {
    private typealias Env = CryptoServiceEnvironment

    public struct Key: RawRepresentable {
        public var rawValue: SecKey

        public init(rawValue: SecKey) {
            self.rawValue = rawValue
        }
    }

    /// Wrapper for the algorithm type.
    /// - Note: Take care when adding new values to this struct. Make sure you have consulted the necessary docs.
    /// - Warning: Avoid adding digest algorithms to this, use 'Message' algorithm types to avoid maintenance mistakes.
    ///
    /// See: https://opensource.apple.com/source/Security/Security-57740.51.3/keychain/SecKey.h.auto.html
    public struct Algorithm {
        let rawValue: SecKeyAlgorithm
    }

    public struct KeyType {
        let rawValue: String
    }

    public struct KeyClass {
        let rawValue: String
    }

    public func sign(_ data: Data, with key: Key, algorithm: Algorithm) throws -> Data {
        var cfError: Unmanaged<CFError>?
        if let signature = Env.secCreateSignature(
            key.rawValue,
            algorithm.rawValue,
            data as CFData,
            &cfError
        ) {
            return signature as Data
        }

        if let cfError = cfError?.takeRetainedValue(), let error = NSError(cfError: cfError) {
            throw error
        }

        throw "Could not sign data \(data) with key \(key.rawValue) using algorithm \(algorithm.rawValue)"
    }

    public func verify(
        signature: Data,
        of data: Data,
        with key: Key,
        using algorithm: Algorithm
    ) throws -> Bool {
        var cfError: Unmanaged<CFError>?
        if CryptoServiceEnvironment.secKeyVerifySignature(
            key.rawValue,
            algorithm.rawValue,
            data as CFData,
            signature as CFData,
            &cfError
        ) {
            return true
        }

        if let cfError = cfError?.takeRetainedValue(), let error = NSError(cfError: cfError) {
            throw error
        }

        return false
    }

    public init() { }
}

private extension NSError {
    convenience init?(cfError: CFError) {
        let domain = CFErrorGetDomain(cfError) as String?
        let code = CFErrorGetCode(cfError) as Int
        let description = CFErrorCopyDescription(cfError) as String?

        guard let domain else { return nil }

        self.init(
            domain: domain as String,
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: description ?? ""
            ]
        )
    }
}

extension CryptoService.KeyClass {
    public static let publicKey = Self(rawValue: kSecAttrKeyClassPublic as String)
    public static let privateKey = Self(rawValue: kSecAttrKeyClassPrivate as String)
}

extension CryptoService.KeyType {
    public static let rsa = Self(rawValue: kSecAttrKeyTypeRSA as String)

    /**
     * According to Apples documentation:
     *
     * `kSecAttrKeyTypeECSECPrimeRandom`: The used curve is P-192, P-256, P-384 or P-521.
     *    The size is specified by `kSecAttrKeySizeInBits` attribute.
     *    Curves are defined in FIPS PUB 186-4 standard.
     * `kSecAttrKeyTypeEC` is the legacy name for `kSecAttrKeyTypeECSECPrimeRandom`.
     *    New applications should not use it.
     */
    public static let elliptic = Self(rawValue: kSecAttrKeyTypeECSECPrimeRandom as String)

    public var stringValue: String {
        rawValue
    }
}

extension CryptoService.Algorithm {
    /// "RSA signature with PKCS#1 padding, SHA-256 digest is generated from input data of any size."
    /// - Note: This algorithm generates the SHA-256 itself.
    public static let rsaSignatureMessagePKCS1v15SHA256: Self = .init(rawValue: .rsaSignatureMessagePKCS1v15SHA256)

    public var stringValue: String {
        rawValue.rawValue as String
    }
}

public extension CryptoService.Key {
    internal typealias Env = CryptoServiceEnvironment

    var data: Data {
        get throws {
            var cfError: Unmanaged<CFError>?
            if let keyData = Env.secKeyCopyData(rawValue, &cfError) {
                return keyData as Data
            }

            if let cfError = cfError?.takeRetainedValue(), let error = NSError(cfError: cfError) {
                throw error
            }

            throw "Couldn't decode key data"
        }
    }

    var publicKey: Self? {
        if let publicKey = Env.secKeyCopyPublicKey(rawValue) {
            return Self(rawValue: publicKey)
        }

        return nil
    }

    init(data: Data, keyType: CryptoService.KeyType, keyClass: CryptoService.KeyClass, keySize: Int) throws {
        let options: [String: Any] = [
            kSecAttrKeyType as String: keyType.rawValue,
            kSecAttrKeySizeInBits as String: keySize,
            kSecAttrKeyClass as String: keyClass.rawValue
        ]

        var cfError: Unmanaged<CFError>?
        guard let key = Env.secKeyCreateWithData(
            data as CFData,
            options as CFDictionary,
            &cfError
        ) else {
            if let cfError = cfError?.takeRetainedValue(), let error = NSError(cfError: cfError) {
                throw error
            }

            let base64 = data.base64EncodedString()
            throw "Could not convert key. keyType: \(keyType) keyClass: \(keyClass) keySize: \(keySize) data: \(base64)"
        }

        self.init(rawValue: key)
    }

    static func random(attrs: [String: Any]) throws -> Self {
        var cfError: Unmanaged<CFError>?

        if let key = Env.secKeyCreateRandom(attrs as CFDictionary, &cfError) {
            return Self(rawValue: key)
        }

        if let cfError = cfError?.takeRetainedValue(), let error = NSError(cfError: cfError) {
            throw error
        }

        throw "Couldn't create key with attrs \(attrs)"
    }
}

extension CryptoService: DependencyKey {
    public static let liveValue: CryptoService = CryptoService()
    #if DEBUG
    public static var testValue: CryptoService = .liveValue
    #endif
}

extension DependencyValues {
    public var cryptoService: CryptoService {
        get { self[CryptoService.self] }
        set { self[CryptoService.self] = newValue }
    }
}
