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

package struct TunnelKeychain: DependencyKey {
    package var storeWireguardConfig: (Data) throws -> Data
    package var clear: () throws -> Void

    package static let liveValue: TunnelKeychain = {
        let keychain = TunnelKeychainImplementation()

        return .init(
            storeWireguardConfig: keychain.store,
            clear: keychain.clear
        )
    }()
}

extension TunnelKeychain {
    package func store(wireguardConfigData data: Data) throws -> Data {
        try storeWireguardConfig(data)
    }

    package func store(wireguardConfigString: String) throws -> Data {
        guard let configData = wireguardConfigString.data(using: .utf8) else {
            throw VPNKeychainError.encodingError
        }

        return try store(wireguardConfigData: configData)
    }
}

extension DependencyValues {
    package var tunnelKeychain: TunnelKeychain {
      get { self[TunnelKeychain.self] }
      set { self[TunnelKeychain.self] = newValue }
    }
}

enum KeychainEnvironment {
    static let secItemAdd = SecItemAdd
    static let secItemDelete = SecItemDelete
    static let secItemCopyMatching = SecItemCopyMatching
    static let secKeyCreateWithData = SecKeyCreateWithData
    static let secKeyVerifySignature = SecKeyVerifySignature
}

struct TunnelKeychainImplementation {
    private enum StorageKey {
        static let wireguardSettings = "ProtonVPN_wg_settings"
    }

    private let encoder = JSONEncoder()

    public func clear() throws {
        try clearPassword(forKey: StorageKey.wireguardSettings)
    }

    // Password is set and retrieved without using the library because NEVPNProtocol requires it to be
    // a "persistent keychain reference to a keychain item containing the password component of the
    // tunneling protocol authentication credential".
    public func getPasswordReference(forKey key: String) throws -> Data {
        var query = formBaseQuery(forKey: key)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecReturnPersistentRef as AnyHashable] = kCFBooleanTrue

        var secItem: AnyObject?
        let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &secItem)
        guard result == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }

        if let item = secItem as? Data {
            return item
        } else {
            throw "TODO: localized error"
        }
    }

    public func setPassword(_ passwordData: Data, forKey key: String) throws {
        guard let existingPasswordData = try getPasswordData(forKey: key) else {
            try setPasswordData(passwordData, forKey: key)
            return
        }

        if existingPasswordData == passwordData {
            return // No need to overwrite the keychain item - the password is unchanged
        }

        try clearPassword(forKey: key) // Attempting to overwrite the keychain item results in `errSecDuplicateItem`
        try setPasswordData(passwordData, forKey: key)
    }

    private func getPasswordData(forKey key: String) throws -> Data? {
        var query = formBaseQuery(forKey: key)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecReturnAttributes as AnyHashable] = kCFBooleanTrue
        query[kSecReturnData as AnyHashable] = kCFBooleanTrue

        var secItem: AnyObject?
        let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &secItem)
        switch result {
        case errSecItemNotFound:
            return nil

        case errSecSuccess:
            guard let secItemDict = secItem as? [String: AnyObject] else {
                throw VPNKeychainError.resultIsNotADictionary
            }
            guard let passwordData = secItemDict[kSecValueData as String] as? Data else {
                throw VPNKeychainError.resultDictionaryHasNoData
            }
            return passwordData

        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }

    private func setPasswordData(_ data: Data, forKey key: String) throws {
        var query = formBaseQuery(forKey: key)
        query[kSecValueData as AnyHashable] = data

        let result = KeychainEnvironment.secItemAdd(query as CFDictionary, nil)
        switch result {
        case errSecSuccess:
            return

        case errSecDuplicateItem:
            throw VPNKeychainError.referenceAlreadyExists

        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }

    @discardableResult private func clearPassword(forKey key: String) throws -> Bool {
        let query = formBaseQuery(forKey: key)
        let result = KeychainEnvironment.secItemDelete(query as CFDictionary)

        switch result {
        case errSecItemNotFound:
            return false

        case errSecSuccess:
            return true

        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }

    private func formBaseQuery(forKey key: String) -> [AnyHashable: Any] {
        return [
            kSecClass as AnyHashable: kSecClassGenericPassword,
            kSecAttrGeneric as AnyHashable: key,
            kSecAttrAccount as AnyHashable: key,
            kSecAttrService as AnyHashable: key,
            kSecAttrAccessible as AnyHashable: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as [AnyHashable: Any]
    }

    // MARK: - Wireguard

    public func store(_ configData: Data) throws -> Data {
        try setPassword(configData, forKey: StorageKey.wireguardSettings)
        return try fetchWireguardConfigurationReference()
    }

    public func fetchWireguardConfigurationReference() throws -> Data {
        return try getPasswordReference(forKey: StorageKey.wireguardSettings)
    }

    public func fetchWireguardConfiguration() throws -> String? {
        var query = formBaseQuery(forKey: StorageKey.wireguardSettings)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecValuePersistentRef as AnyHashable] = try fetchWireguardConfigurationReference()
        query[kSecReturnData as AnyHashable] = true

        var secItem: AnyObject?
        let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &secItem)
        if result != errSecSuccess {
            log.error("Keychain error", category: .keychain, metadata: ["SecItemCopyMatching": "\(result)"])
            return nil
        }

        if let item = secItem as? Data {
            let config = String(data: item, encoding: String.Encoding.utf8)
            log.debug("Config read", category: .keychain, metadata: ["config": "\(config ?? "-")"])
            return config

        } else {
            log.error("Keychain error: can't read data", category: .keychain)
            return nil
        }
    }
}

enum VPNKeychainError: Error {
    case encodingError
    case referenceAlreadyExists
    case resultIsNotADictionary
    case resultDictionaryHasNoData
}
