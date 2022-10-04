// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Foundation
import Security

class Keychain {
    static func openReference(called ref: Data) -> Data? {
        var result: CFTypeRef?
        let ret = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecValuePersistentRef: ref,
            kSecReturnData: true
        ] as CFDictionary, &result)
        if ret != errSecSuccess || result == nil {
            wg_log(.error, message: "Unable to open config from keychain: \(ret)")
            return nil
        }
        return result as? Data
    }

    static func makeReference(containing value: String, called name: String, previouslyReferencedBy oldRef: Data? = nil) -> Data? {
        var ret: OSStatus
        guard let bundleIdentifier = bundleIdentifier else {
            wg_log(.error, staticMessage: "Unable to determine bundle identifier")
            return nil
        }
        let itemLabel = "ProtonVPN WireGuard: \(name)"
        var items: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: itemLabel,
            kSecAttrDescription: "wg-quick(8) config",
            kSecAttrService: bundleIdentifier,
            kSecValueData: value.data(using: .utf8) as Any,
            kSecReturnPersistentRef: true
        ]

        #if os(iOS)
        items[kSecAttrAccessGroup] = FileManager.appGroupId
        items[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        #elseif os(macOS)
        items[kSecAttrSynchronizable] = false
        items[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        #else
        #error("Unimplemented")
        #endif

        var ref: CFTypeRef?
        ret = SecItemAdd(items as CFDictionary, &ref)
        if ret != errSecSuccess || ref == nil {
            wg_log(.error, message: "Unable to add config to keychain: \(ret)")
            return nil
        }
        if let oldRef = oldRef {
            deleteReference(called: oldRef)
        }
        return ref as? Data
    }

    static func deleteReference(called ref: Data) {
        let ret = SecItemDelete([kSecValuePersistentRef: ref] as CFDictionary)
        if ret != errSecSuccess {
            wg_log(.error, message: "Unable to delete config from keychain: \(ret)")
        }
    }

    static func deleteReferences(except whitelist: Set<Data>) {
        var result: CFTypeRef?
        let ret = SecItemCopyMatching([kSecClass: kSecClassGenericPassword,
                                       kSecAttrService: Bundle.main.bundleIdentifier as Any,
                                       kSecMatchLimit: kSecMatchLimitAll,
                                       kSecReturnPersistentRef: true] as CFDictionary,
                                      &result)
        if ret != errSecSuccess || result == nil {
            return
        }
        guard let items = result as? [Data] else { return }
        for item in items {
            if !whitelist.contains(item) {
                deleteReference(called: item)
            }
        }
    }

    static func verifyReference(called ref: Data) -> Bool {
        return SecItemCopyMatching([kSecClass: kSecClassGenericPassword,
                                    kSecValuePersistentRef: ref] as CFDictionary,
                                   nil) != errSecItemNotFound
    }

    // MARK: - By name (for macOS sysex)

    static func loadWgConfig() -> Data? {
        var query = getDefaultQuery()
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                wg_log(.error, staticMessage: "Error reading from keychain: can't decode data or data is empty.")
                return nil
            }
            return data

        default:
            wg_log(.error, message: "Error reading from keychain: \(status).")
            return nil
        }
    }

    static func saveWgConfig(_ data: Data) -> Bool {
        if let oldData = Self.loadWgConfig() {
            if oldData == data {
                wg_log(.debug, message: "New value is the same as the old (\(data.hashValue)). Will not write to keychain.")
                return true
            } else {
                wg_log(.debug, staticMessage: "Old value found in the keychain. Will delete it.")
                Self.deleteWgConfig()
            }
        } else {
            wg_log(.debug, staticMessage: "No config in the keychain. Will write new.")
        }

        var query = getDefaultQuery()
        query[kSecClass] = kSecClassGenericPassword
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecValueData] = data
        query[kSecAttrLabel] = "ProtonVPN WireGuard config"

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            wg_log(.error, message: "Error writing to keychain: \(status).")
            return false
        }
        return true
    }

    static func deleteWgConfig() {
        let query = getDefaultQuery()

        let ret = SecItemDelete(query as CFDictionary)
        if ret != errSecSuccess {
            wg_log(.error, message: "Unable to delete config from keychain: \(ret)")
        }
    }

    private static var bundleIdentifier: String? {
        guard var bundleIdentifier = Bundle.main.bundleIdentifier else {
            wg_log(.error, staticMessage: "Unable to determine bundle identifier")
            return nil
        }
        if bundleIdentifier.hasSuffix(".WireGuard-Extension") {
            bundleIdentifier.removeLast(".WireGuard-Extension".count)
        }
        return bundleIdentifier
    }

    private static func getDefaultQuery() -> [CFString: Any] {
        var query = [CFString: Any]()

        query[kSecAttrAccount] = "ProtonVPN WG"
        query[kSecClass as CFString] = kSecClassGenericPassword

        if let bundleIdentifier = bundleIdentifier {
            query[kSecAttrService as CFString] = bundleIdentifier
        }

        return query
    }

}
