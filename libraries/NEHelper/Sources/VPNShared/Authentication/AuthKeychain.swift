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
    func fetch(forContext: AppContext?) async -> AuthCredentials?
    func store(_ credentials: AuthCredentials, forContext: AppContext?) async throws
    func clear() async
}

public extension AuthKeychainHandle {
    func fetch() async -> AuthCredentials? {
        await fetch(forContext: nil)
    }

    func store(_ credentials: AuthCredentials) async throws {
        try await store(credentials, forContext: nil)
    }
}

public protocol AuthKeychainHandleFactory {
    func makeAuthKeychainHandle() -> AuthKeychainHandle
}

public struct AuthKeychainHandleDependencyKey: DependencyKey {
    public static var liveValue: AuthKeychainHandle {
        AuthKeychain.default
    }

    #if DEBUG
    public static var testValue = liveValue
    #endif
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

    public static func fetch() async -> AuthCredentials? {
        await `default`.fetch()
    }

    public static func store(_ credentials: AuthCredentials) async throws {
        try await `default`.store(credentials)
    }

    public static func clear() async {
        await `default`.clear()
    }
    private let keychain = KeychainActor.default

    @Dependency(\.appContext) private var context
}

extension AuthKeychain: AuthKeychainHandle {
    private var defaultStorageKey: String {
        storageKey(forContext: context) ?? StorageKey.authCredentials
    }

    private func storageKey(forContext context: AppContext) -> String? {
        StorageKey.contextKeys[context]
    }

    public func fetch(forContext context: AppContext?) async -> AuthCredentials? {
        NSKeyedUnarchiver.setClass(AuthCredentials.self, forClassName: "ProtonVPN.AuthCredentials")
        var key = defaultStorageKey
        if let context = context, let contextKey = storageKey(forContext: context) {
            key = contextKey
        }

        let data: Data
        do {
            guard let keychainData = try keychain.getData(key) else {
                throw "No data in the keychain"
            }
            data = keychainData
        } catch let error {
            log.error("Keychain (auth) read error", category: .keychain, metadata: ["error": "\(error)"])
            return nil
        }

        do {
            return try JSONDecoder().decode(AuthCredentials.self, from: data)
        } catch {
            do {
                /// We tried decoding with JSON and failed, let's try to decode from NSKeyedUnarchiver,
                /// but first let's remove the stored data in case the NSKeyedUnarchiver crashes.
                /// Next time user launches the app, the credentials will be lost, but at least
                /// we won't start a crash cycle from which the user can't recover.
                try? keychain.remove(key)
                log.info("Removed AuthKeychain storage for \(key) key before attempting to unarchive with NSKeyedUnarchiver", category: .keychain)
                if let unarchivedObject = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [AuthCredentials.self,
                                                                                             NSString.self,
                                                                                             NSData.self],
                                                                                 from: data),
                   let authCredentials = unarchivedObject as? AuthCredentials {
                    try? store(authCredentials, forContext: context) // store in JSON
                    log.info("AuthKeychain storage for \(key) migration successful!", category: .keychain)
                    return authCredentials
                }
            } catch let error {
                log.error("Keychain (auth) read error", category: .keychain, metadata: ["error": "\(error)"])
            }
        }

        return nil
    }

    public func store(_ credentials: AuthCredentials, forContext context: AppContext?) async throws {
        NSKeyedArchiver.setClassName("ProtonVPN.AuthCredentials", for: AuthCredentials.self)

        var key = defaultStorageKey
        if let context = context, let contextKey = storageKey(forContext: context) {
            key = contextKey
        }

        do {
            let data = try JSONEncoder().encode(credentials)
            try keychain.set(data, key: key)
        } catch let error {
            log.error("Keychain (auth) write error: \(error). Will clean and retry.", category: .keychain, metadata: ["error": "\(error)"])
            do { // In case of error try to clean keychain and retry with storing data
                clear()
                let data = try JSONEncoder().encode(credentials)
                try keychain.set(data, key: key)
            } catch let error2 {
                #if os(macOS)
                    log.error("Keychain (auth) write error: \(error2). Will lock keychain to try to recover from this error.", category: .keychain, metadata: ["error": "\(error2)"])
                    do { // Last chance. Locking/unlocking keychain sometimes helps.
                        SecKeychainLock(nil)
                        let data = try JSONEncoder().encode(credentials)
                        try keychain.set(data, key: key)
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

    public func clear() async {
        await keychain.clear(contextValues: Array<String>(StorageKey.contextKeys.values))
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.clearNotification, object: nil, userInfo: nil)
        }
    }
}
