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
import Sharing

/// A `SharedKey` that persists a `Codable` value as JSON `Data` in `UserDefaults`, under a fixed
/// (non-per-user) key.
public struct JSONAppStorageKey<Value: Sendable>: SharedKey {
    private let key: String
    private let store: UncheckedSendable<UserDefaults>
    private let decode: @Sendable (UserDefaults, String) throws -> Value
    private let encode: @Sendable (Value, UserDefaults, String) throws -> Void

    /// The id includes both the key name and which UserDefaults it lives in. `swift-sharing` reuses one
    /// cached value per id, so the same key name in two different UserDefaults must count as two
    /// different things — otherwise they'd wrongly share one value.
    public struct ID: Hashable, Sendable {
        fileprivate let key: String
        fileprivate let store: ObjectIdentifier
    }

    public var id: ID {
        ID(key: key, store: ObjectIdentifier(store.wrappedValue))
    }

    init(
        key: String,
        decode: @escaping @Sendable (UserDefaults, String) throws -> Value,
        encode: @escaping @Sendable (Value, UserDefaults, String) throws -> Void
    ) {
        @Dependency(\.defaultAppStorage) var store
        self.key = key
        self.store = UncheckedSendable(store)
        self.decode = decode
        self.encode = encode
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        do {
            try continuation.resume(returning: decode(store.wrappedValue, key))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        // Capture the resolved store/key/decoder: the observer escapes the dependency scope this
        // reference was created in, so it must not touch `@Dependency` itself
        let store = store.wrappedValue
        let key = key
        let decode = decode
        let gate = ChangeGate(initial: store.data(forKey: key))
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            guard gate.isChange(store.data(forKey: key)) else { return }
            do {
                try subscriber.yield(decode(store, key))
            } catch {
                subscriber.yield(with: .failure(error))
            }
        }
        return SharedSubscription {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func save(_ value: Value, context _: SaveContext, continuation: SaveContinuation) {
        do {
            try encode(value, store.wrappedValue, key)
            continuation.resume()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - Encodings

public extension JSONAppStorageKey {
    /// A key for an optional `Codable` value stored as JSON `Data`.
    /// Absence of a stored value reads as `nil`; writing `nil` removes the key. Corrupt stored data throws
    static func json<Wrapped: Codable & Sendable>(
        _ key: String
    ) -> JSONAppStorageKey<Wrapped?> {
        JSONAppStorageKey<Wrapped?>(
            key: key,
            decode: { store, key in
                guard let data = store.data(forKey: key) else { return nil }
                return try JSONDecoder().decode(Wrapped.self, from: data)
            },
            encode: { value, store, key in
                if let value {
                    let data = try JSONEncoder().encode(value)
                    store.set(data, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
            }
        )
    }

    /// A key for a non-optional `Codable` value stored as JSON `Data`, falling back to
    /// `defaultValue` when nothing is stored . Corrupt stored data throws
    static func json<Wrapped: Codable & Sendable>(
        _ key: String,
        default defaultValue: Wrapped
    ) -> JSONAppStorageKey<Wrapped> {
        JSONAppStorageKey<Wrapped>(
            key: key,
            decode: { store, key in
                guard let data = store.data(forKey: key) else { return defaultValue }
                return try JSONDecoder().decode(Wrapped.self, from: data)
            },
            encode: { value, store, key in
                let data = try JSONEncoder().encode(value)
                store.set(data, forKey: key)
            }
        )
    }
}
