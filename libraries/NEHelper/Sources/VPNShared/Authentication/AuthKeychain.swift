//
//  AuthKeychain.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import KeychainAccess
import Dependencies

public protocol AuthKeychainHandle {
    func fetch(forContext: AppContext?) -> AuthCredentials?
    func store(_ credentials: AuthCredentials, forContext: AppContext?) throws
    func clear()
}

public extension AuthKeychainHandle {
    func fetch() -> AuthCredentials? {
        fetch(forContext: nil)
    }

    func store(_ credentials: AuthCredentials) throws {
        try store(credentials, forContext: nil)
    }
}

public protocol AuthKeychainHandleFactory {
    func makeAuthKeychainHandle() -> AuthKeychainHandle
}

public struct AuthKeychainHandleDependencyKey: DependencyKey {
    public static var liveValue: AuthKeychainHandle {
        AuthKeychain.default
    }
}

extension DependencyValues {
    public var authKeychain: AuthKeychainHandle {
        get { self[AuthKeychainHandleDependencyKey.self] }
        set { self[AuthKeychainHandleDependencyKey.self] = newValue }
    }
}

public class AuthKeychain {
    public static let clearNotification = Notification.Name("AuthKeychain.clear")

    private struct StorageKey {
        static let authCredentials = "authCredentials"

        static let contextKeys: [AppContext: String] = [
            .mainApp: authCredentials,
            .wireGuardExtension: "\(authCredentials)_\(AppContext.wireGuardExtension)"
        ]
    }

    public static let `default`: AuthKeychainHandle = AuthKeychain()

    public static func fetch() -> AuthCredentials? {
        `default`.fetch()
    }

    public static func store(_ credentials: AuthCredentials) throws {
        try `default`.store(credentials)
    }

    public static func clear() {
        `default`.clear()
    }

    private let keychain: KeychainAccess.Keychain
    @Dependency(\.appContext) private var context

    /// This is fileprivate for a reason. Please use `default`.
    fileprivate init() {
        self.keychain = .init(service: KeychainConstants.appKeychain)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }
}

extension AuthKeychain: AuthKeychainHandle {
    private var defaultStorageKey: String {
        storageKey(forContext: context) ?? StorageKey.authCredentials
    }

    private func storageKey(forContext context: AppContext) -> String? {
        StorageKey.contextKeys[context]
    }

    public func fetch(forContext context: AppContext?) -> AuthCredentials? {
        NSKeyedUnarchiver.setClass(AuthCredentials.self, forClassName: "ProtonVPN.AuthCredentials")
        var key = defaultStorageKey
        if let context = context, let contextKey = storageKey(forContext: context) {
            key = contextKey
        }

        do {
            if let data = try keychain.getData(key) {
                if let unarchivedObject = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [AuthCredentials.self, NSString.self, NSData.self], from: data)),
                   let authCredentials = unarchivedObject as? AuthCredentials {
                    return authCredentials
                }
            }
        } catch let error {
            log.error("Keychain (auth) read error: \(error)", category: .keychain)
        }

        return nil
    }

    public func store(_ credentials: AuthCredentials, forContext context: AppContext?) throws {
        NSKeyedArchiver.setClassName("ProtonVPN.AuthCredentials", for: AuthCredentials.self)

        var key = defaultStorageKey
        if let context = context, let contextKey = storageKey(forContext: context) {
            key = contextKey
        }

        do {
            try keychain.set(NSKeyedArchiver.archivedData(withRootObject: credentials, requiringSecureCoding: true), key: key)
        } catch let error {
            log.error("Keychain (auth) write error: \(error). Will clean and retry.", category: .keychain, metadata: ["error": "\(error)"])
            do { // In case of error try to clean keychain and retry with storing data
                clear()
                try keychain.set(NSKeyedArchiver.archivedData(withRootObject: credentials, requiringSecureCoding: true), key: key)
            } catch let error2 {
                #if os(macOS)
                    log.error("Keychain (auth) write error: \(error2). Will lock keychain to try to recover from this error.", category: .keychain, metadata: ["error": "\(error2)"])
                    do { // Last chance. Locking/unlocking keychain sometimes helps.
                        SecKeychainLock(nil)
                        try keychain.set(NSKeyedArchiver.archivedData(withRootObject: credentials, requiringSecureCoding: true), key: key)
                    } catch let error3 {
                        log.error("Keychain (auth) write error. Giving up.", category: .keychain, metadata: ["error": "\(error3)"])
                        throw error3
                    }
                #else
                log.error("Keychain (auth) write error. Giving up.", category: .keychain, metadata: ["error": "\(error2)"])
                    throw error2
                #endif
            }
        }
    }

    public func clear() {
        for storageKey in StorageKey.contextKeys.values {
            keychain[data: storageKey] = nil
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.clearNotification, object: nil, userInfo: nil)
        }
    }
}
