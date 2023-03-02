//
//  Networking.swift
//  Core
//
//  Created by Igor Kulman on 23.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking
import VPNShared
import KeychainAccess

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

    private let keychain: KeychainAccess.Keychain

    public init() {
        self.keychain = .init(service: KeychainConstants.appKeychain)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

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
