//
//  Created on 05.03.2022.
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
import KeychainAccess
import class ProtonCoreNetworking.AuthCredential
import class VPNShared.KeychainActor

public protocol UnauthKeychainHandleFactory {
    func makeUnauthKeychainHandle() -> UnauthKeychainHandle
}

public protocol UnauthKeychainHandle {
    func fetch() -> AuthCredential?
    func store(_ credentials: AuthCredential)
    func clear()
}

public final class UnauthKeychain: UnauthKeychainHandle {

    private struct StorageKey {
        static let unauthSessionCredentials = "unauthSessionCredentials"
    }

    private let keychain = KeychainActor()

    public init() { }

    public func fetch() -> AuthCredential? {
        do {
            guard let data = try keychain.getData(StorageKey.unauthSessionCredentials) else {
                return nil
            }
            return AuthCredential.unarchive(data: data as NSData)
        } catch let error {
            log.error("Keychain (unauth) read error: \(error)", category: .keychain)
            return nil
        }
    }

    public func store(_ credentials: AuthCredential) {
        do {
            try keychain.set(credentials.archive(), key: StorageKey.unauthSessionCredentials)
            log.debug("Keychain (unauth) session stored", category: .keychain)
        } catch {
            log.error("Keychain (unauth) write error: \(error)", category: .keychain)
        }
    }

    public func clear() {
        do {
            try keychain.remove(StorageKey.unauthSessionCredentials)
        } catch {
            log.error("Keychain (unauth) clear error: \(error)", category: .keychain)
        }
    }
}
