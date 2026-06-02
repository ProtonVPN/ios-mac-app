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

import ConnectionShared
import CryptoKit
import Dependencies
import Foundation
import os
import VPNCoreTypes

final class SecurePersistentCache: PersistentCache {
    private let service: String

    init(keychainServiceSuffix: String) {
        self.service = "ProTUN_" + keychainServiceSuffix
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

    func get(key: CacheKey) -> Data? {
        @Dependency(\.lightKeychain) var lightKeychain

        let (status, data) = lightKeychain.getPassword(service: service, account: key.keychainAccount)

        guard status == errSecSuccess, let data else {
            Logger.adapter.error("Failed to retrieve Keychain item for \(key, privacy: .public): \(describe(status), privacy: .public)")
            return nil
        }

        return data
    }

    func clear() {
        @Dependency(\.lightKeychain) var lightKeychain

        let status = lightKeychain.clear(service: service)

        if status != errSecSuccess, status != errSecItemNotFound {
            Logger.adapter.error("Failed to clear Keychain items: \(describe(status), privacy: .public)")
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

extension CacheKey: CustomStringConvertible {
    public var description: String {
        switch self {
        case .certificate:
            "certificate"
        case .privateKey:
            "privateKey"
        case .apiSession:
            "apiSession"
        }
    }
}
