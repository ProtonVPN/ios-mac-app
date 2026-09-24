//
//  Created on 03.09.2026 by Larissa Perara.
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
import Foundation
import Sharing

// MARK: - ManagedDomainReader

/// Support for MDM managed devices and reading specific domains according to how the associated values are read into user defaults. 
public struct ManagedDomainReader: Sendable {
    public var rawValue: @Sendable (_ key: String) -> Any?
    
    public init(rawValue: @Sendable @escaping (_: String) -> Any? = { _ in nil }) {
        self.rawValue = rawValue
    }
}

extension ManagedDomainReader: DependencyKey {
    public static var liveValue: ManagedDomainReader {
        #if os(iOS)
        .init(rawValue: { key in
            let store = UserDefaults.standard
            let managedKey = "com.apple.configuration.managed"
            guard let managedDictionary = store.dictionary(forKey: managedKey) else {
                return nil
            }
            return managedDictionary[key]
        })
        #elseif os(macOS)
        .init(rawValue: { key in
            @Dependency(\.defaultAppStorage) var store
            guard store.objectIsForced(forKey: key) else { return nil }
            return store.object(forKey: key)
        })
        #else
        .init()
        #endif
    }
}

// MARK: DependencyValues (ManagedDomainReader)

extension DependencyValues {
    public var managedDomainReader: ManagedDomainReader {
        get { self[ManagedDomainReader.self] }
        set { self[ManagedDomainReader.self] = newValue }
    }
}

// MARK: - MDMAppStorageKey

/// A read-only `SharedReaderKey` that reads a value from `UserDefaults` using a caller-supplied
/// derivation closure for MDM-managed configurations.
///
/// The derivation closure receives the `UserDefaults` instance and the key string so that it can
/// read raw primitive values, JSON-decode compound types, or derive the result from multiple keys.
///
/// Subscriptions are driven by `UserDefaults.didChangeNotification`. Duplicate notifications for the
/// same value are suppressed by a `ChangeGate`.
public struct MDMAppStorageKey<Value: Sendable>: SharedReaderKey {
    private let key: String
    private let store: UncheckedSendable<UserDefaults>
    private let domainReader: ManagedDomainReader
    private let read: @Sendable (Any?) -> Value
    
    /// The id retains the storage key name and the identity of the `UserDefaults` instance.
    ///
    /// `swift-sharing` reuses one cached value per id, requiring the same key in two distinct stores
    ///    to be two distinct objects, this means two keys with the same key and a different default or callback
    ///    would register as the same key.
    public struct ID: Hashable, Sendable {
        fileprivate let key: String
        fileprivate let store: ObjectIdentifier
    }
    
    public var id: ID {
        ID(key: key, store: ObjectIdentifier(store.wrappedValue))
    }
    
    init(key: String,
         read: @escaping @Sendable (Any?) -> Value
    ) {
        @Dependency(\.defaultAppStorage) var store
        @Dependency(\.managedDomainReader) var reader

        self.key = key
        self.store = UncheckedSendable(store)
        self.domainReader = reader
        self.read = read
    }
    
    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        let raw = domainReader.rawValue(key)
        continuation.resume(returning: read(raw))
    }
    
    public func subscribe(context _: LoadContext<Value>, subscriber: SharedSubscriber<Value>) -> SharedSubscription {
        let store = store.wrappedValue
        let key = key
        let read = read
        
        let initialValue = read(domainReader.rawValue(key))
        let gate = ChangeGate(initial: initialValue)
        
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            let newValue = read(domainReader.rawValue(key))
            guard gate.isChange(newValue) else { return }
            subscriber.yield(newValue)
        }
        return SharedSubscription {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - MDM Specific Definitions

// MARK: Bool Support

public extension MDMAppStorageKey where Value == Bool {
    /// A read only key that reads a raw `Bool` from `UserDefaults`.
    ///
    /// Returns `defaultValue` when the key is not set, or when MDM is not relevant for this device.
    static func mdmBool(_ key: String, default defaultValue: Bool) -> MDMAppStorageKey<Bool> {
        MDMAppStorageKey<Bool>(key: key) { raw in
            guard let number = raw as? NSNumber else {
                return defaultValue
            }
            
            return number.boolValue
        }
    }
}

// MARK: String Support

public extension MDMAppStorageKey where Value == String? {
    /// A read only key that reads a `String` from `UserDefaults`
    ///
    /// Returns `nil` when the key is not set, or when MDM is not relevant for this device.
    static func mdmString(_ key: String) -> MDMAppStorageKey<String?> {
        MDMAppStorageKey<String?>(key: key) { raw in raw as? String }
    }
}
