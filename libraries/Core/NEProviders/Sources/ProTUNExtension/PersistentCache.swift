//
//  Created on 06/05/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import CryptoKit
import Dependencies
import Foundation
import os
import protun

final class SecurePersistentCache: PersistentCache {
    /// Every cache service starts with this, followed by a hash of the user ID.
    private static let servicePrefix = "ProTUN_"

    private let service: String

    init(userID: String) {
        let suffix = Self.cacheSuffix(for: userID)
        Logger.adapter.debug("Initialising SecurePersistentCache with suffix: \"\(suffix, privacy: .public)\"")
        self.service = Self.servicePrefix + suffix
    }

    private static func cacheSuffix(for userID: String) -> String {
        let digest = SHA256.hash(data: Data(userID.utf8))
        // 16 bytes is enough to prevent collisions for users sharing one device
        let prefix = Data(digest.prefix(16))
        return prefix.base64EncodedString()
    }

    func put(key: CacheKey, bytes: Data) {
        @Dependency(\.lightKeychain) var lightKeychain

        let updateStatus = lightKeychain.updateStatus(service: service, account: key.keychainAccount, bytes: bytes)
        switch updateStatus {
        case errSecSuccess:
            Logger.adapter.debug("Updated Keychain item for \(key, privacy: .public)")
        case errSecItemNotFound:
            let addStatus = lightKeychain.addPassword(service: service, account: key.keychainAccount, bytes: bytes)
            if addStatus == errSecSuccess {
                Logger.adapter.debug("Added Keychain item for \(key, privacy: .public)")
            } else {
                Logger.adapter.error("Failed to add Keychain item for \(key, privacy: .public): \(describe(addStatus), privacy: .public)")
            }
        default:
            Logger.adapter.error("Failed to update Keychain item for \(key, privacy: .public): \(describe(updateStatus), privacy: .public)")
        }
    }

    func remove(key: CacheKey) {
        @Dependency(\.lightKeychain) var lightKeychain

        let status = lightKeychain.removePassword(service: service, account: key.keychainAccount)

        switch status {
        case errSecSuccess:
            Logger.adapter.debug("Removed Keychain item for \(key, privacy: .public)")
        case errSecItemNotFound:
            Logger.adapter.debug("No Keychain item to remove for \(key, privacy: .public)")
        default:
            Logger.adapter.error("Failed to remove Keychain item for \(key, privacy: .public): \(describe(status), privacy: .public)")
        }
    }

    func get(key: CacheKey) -> Data? {
        @Dependency(\.lightKeychain) var lightKeychain

        let (status, data) = lightKeychain.getPassword(service: service, account: key.keychainAccount)

        guard status == errSecSuccess, let data else {
            Logger.adapter.error("Failed to retrieve Keychain item for \(key, privacy: .public): \(describe(status), privacy: .public)")
            return nil
        }

        return data
    }

    func clearAll() {
        @Dependency(\.lightKeychain) var lightKeychain

        let status = lightKeychain.clear(service: service)

        if status != errSecSuccess, status != errSecItemNotFound {
            Logger.adapter.error("Failed to clear Keychain items: \(describe(status), privacy: .public)")
        }
    }

    /// Clears the cache of every user on this device. Prevents reuse of sessions after signing out.
    static func clearAllUsers() {
        @Dependency(\.lightKeychain) var lightKeychain

        let (status, services) = lightKeychain.services()
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Logger.adapter.error("Failed to list Keychain services: \(describe(status), privacy: .public)")
            return
        }

        for service in services where service.hasPrefix(servicePrefix) {
            let status = lightKeychain.clear(service: service)
            if status == errSecSuccess || status == errSecItemNotFound {
                Logger.adapter.info("Cleared Keychain items for \(service, privacy: .public)")
            } else {
                Logger.adapter.error("Failed to clear Keychain items for \(service, privacy: .public): \(describe(status), privacy: .public)")
            }
        }
    }
}

private func describe(_ status: OSStatus) -> String {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
    return "\(message) (OSStatus \(status))"
}

extension CacheKey {
    var keychainAccount: String {
        description
    }
}
