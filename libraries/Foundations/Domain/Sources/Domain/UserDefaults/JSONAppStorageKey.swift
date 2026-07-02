//
//  Created on 02/07/2026 by Max Kupetskyi.
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
import os
import Sharing

/// A `SharedKey` that persists a `Codable` value as JSON `Data` in `UserDefaults`, under a fixed
/// (non-per-user) key.
///
/// This reproduces the legacy `PropertiesManager` `@Property` / `@InitializedProperty`
/// representation byte-for-byte (a JSON-encoded `Data` blob stored via
/// `Storage.set`/`Storage.get`), so values written by previous app versions are read
/// transparently, with no migration step.
///
/// The underlying `UserDefaults` suite is the one configured for swift-sharing
/// (`\.defaultAppStorage`) — the same suite the legacy storage targeted once the app aligns its
/// default store. Use the ``json(_:)`` factory for an optional value (absence reads as `nil`) or
/// ``json(_:default:)`` for a non-optional value with a fallback default.
///
/// `subscribe` observes `UserDefaults.didChangeNotification` and only forwards when the raw `Data`
/// at this key actually changes, so a write to an unrelated key in the suite does not produce a
/// redundant emission.
public final class JSONAppStorageKey<Value: Sendable>: SharedKey {
    private let key: String
    private let decode: @Sendable (UserDefaults, String) -> Value
    private let encode: @Sendable (Value, UserDefaults, String) -> Void

    public var id: some Hashable {
        key
    }

    init(
        key: String,
        decode: @escaping @Sendable (UserDefaults, String) -> Value,
        encode: @escaping @Sendable (Value, UserDefaults, String) -> Void
    ) {
        self.key = key
        self.decode = decode
        self.encode = encode
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        @Dependency(\.defaultAppStorage) var store
        continuation.resume(returning: decode(store, key))
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        @Dependency(\.defaultAppStorage) var store
        let key = key
        let decode = decode
        let lastData = OSAllocatedUnfairLock<Data?>(initialState: store.data(forKey: key))
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            // `didChangeNotification` fires for *any* key in the suite; forward only on real
            // changes to this key's stored bytes.
            let newData = store.data(forKey: key)
            let changed = lastData.withLock { current -> Bool in
                guard current != newData else { return false }
                current = newData
                return true
            }
            guard changed else { return }
            subscriber.yield(decode(store, key))
        }
        return SharedSubscription {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func save(_ value: Value, context _: SaveContext, continuation: SaveContinuation) {
        @Dependency(\.defaultAppStorage) var store
        encode(value, store, key)
        continuation.resume()
    }
}

// MARK: - Encodings

public extension JSONAppStorageKey {
    /// A key for an optional `Codable` value stored as JSON `Data` (matching the legacy
    /// `@Property` representation). Absence of a stored value reads as `nil`; writing `nil`
    /// removes the key.
    static func json<Wrapped: Codable & Sendable>(
        _ key: String
    ) -> JSONAppStorageKey<Wrapped?> {
        JSONAppStorageKey<Wrapped?>(
            key: key,
            decode: { store, key in
                guard let data = store.data(forKey: key) else { return nil }
                return try? JSONDecoder().decode(Wrapped.self, from: data)
            },
            encode: { value, store, key in
                if let value, let data = try? JSONEncoder().encode(value) {
                    store.set(data, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
            }
        )
    }

    /// A key for a non-optional `Codable` value stored as JSON `Data`, falling back to
    /// `defaultValue` when nothing is stored (matching the legacy `@InitializedProperty`
    /// representation).
    static func json<Wrapped: Codable & Sendable>(
        _ key: String,
        default defaultValue: Wrapped
    ) -> JSONAppStorageKey<Wrapped> {
        JSONAppStorageKey<Wrapped>(
            key: key,
            decode: { store, key in
                guard
                    let data = store.data(forKey: key),
                    let value = try? JSONDecoder().decode(Wrapped.self, from: data)
                else { return defaultValue }
                return value
            },
            encode: { value, store, key in
                if let data = try? JSONEncoder().encode(value) {
                    store.set(data, forKey: key)
                }
            }
        )
    }
}
