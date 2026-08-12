//
//  Created on 01/06/2026.
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

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct LightKeychain {
    var updateStatus: @Sendable (_ service: String, _ account: String, _ bytes: Data) -> OSStatus = { _, _, _ in .zero }
    var addPassword: @Sendable (_ service: String, _ account: String, _ bytes: Data) -> OSStatus = { _, _, _ in .zero }
    var getPassword: @Sendable (_ service: String, _ account: String) -> (OSStatus, Data?) = { _, _ in (.zero, nil) }
    var removePassword: @Sendable (_ service: String, _ account: String) -> OSStatus = { _, _ in .zero }
    var clear: @Sendable (_ service: String) -> OSStatus = { _ in .zero }
}

extension LightKeychain: DependencyKey {
    static let liveValue: LightKeychain = .init { service, account, bytes in
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary

        return SecItemUpdate(query, [kSecValueData: bytes] as CFDictionary)
    } addPassword: { service, account, bytes in
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: bytes,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary

        return SecItemAdd(query, nil)
    } getPassword: { service, account in
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        if status == errSecSuccess {
            return (status, result as? Data)
        } else {
            return (status, nil)
        }
    } removePassword: { service, account in
        SecItemDelete(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as CFDictionary
        )
    } clear: { service in
        SecItemDelete(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
            ] as CFDictionary
        )
    }
}

extension DependencyValues {
    var lightKeychain: LightKeychain {
        get { self[LightKeychain.self] }
        set { self[LightKeychain.self] = newValue }
    }
}
