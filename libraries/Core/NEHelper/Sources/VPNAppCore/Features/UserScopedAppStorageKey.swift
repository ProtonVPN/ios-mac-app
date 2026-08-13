//
//  Created on 10/06/2026 by Max Kupetskyi.
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
import Domain
import Foundation
import Sharing
import VPNShared

/// Which authenticated-user identifier a ``UserScopedAppStorageKey``'s on-disk key is scoped to.
public enum UserScope: Sendable {
    /// `baseKey + authKeychain.username` — the default
    case username
    /// `baseKey + authKeychain.userId`
    case userId
}

/// A `SharedKey` that persists a value in `UserDefaults` under a *per-user* key.
public struct UserScopedAppStorageKey<Value: Sendable>: SharedKey {
    /// Identity of the storage location: the resolved per-user key (or the base key while logged
    /// out, kept so distinct features don't collide on `resolvedKey == nil`) plus the suite object.
    public struct ID: Hashable, Sendable {
        fileprivate let baseKey: String
        fileprivate let resolvedKey: String?
        fileprivate let store: ObjectIdentifier
    }

    private let baseKey: String
    /// `baseKey + user identifier`, or `nil` when no user was logged in at construction time.
    private let resolvedKey: String?
    private let store: UncheckedSendable<UserDefaults>
    private let valueWhenNoUser: Value
    private let decode: @Sendable (UserDefaults, String) -> Value
    private let encode: @Sendable (Value, UserDefaults, String) -> Void

    public var id: ID {
        ID(
            baseKey: baseKey,
            resolvedKey: resolvedKey,
            store: ObjectIdentifier(store.wrappedValue)
        )
    }

    /// Whether a logged-in user was resolved when this key was constructed. When `false`, loads
    /// return `valueWhenNoUser` and writes are no-ops.
    public var isBoundToUser: Bool {
        resolvedKey != nil
    }

    init(
        baseKey: String,
        scope: UserScope = .username,
        valueWhenNoUser: Value,
        decode: @escaping @Sendable (UserDefaults, String) -> Value,
        encode: @escaping @Sendable (Value, UserDefaults, String) -> Void
    ) {
        @Dependency(\.authKeychain) var authKeychain
        @Dependency(\.defaultAppStorage) var defaults

        let identifier: String? = switch scope {
        case .username:
            authKeychain.username
        case .userId:
            authKeychain.userId
        }

        self.baseKey = baseKey
        self.resolvedKey = identifier.map { baseKey + $0 }
        self.store = UncheckedSendable(defaults)
        self.valueWhenNoUser = valueWhenNoUser
        self.decode = decode
        self.encode = encode
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        guard let key = resolvedKey else {
            continuation.resume(returning: valueWhenNoUser)
            return
        }
        continuation.resume(returning: decode(store.wrappedValue, key))
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        // No logged-in user: the value is the constant `valueWhenNoUser`; nothing to observe.
        guard let key = resolvedKey else { return SharedSubscription {} }

        // Capture the resolved store/key/decoder. The observer closure escapes the dependency
        // scope the key was created in, so it must not touch `@Dependency` itself.
        let store = store.wrappedValue
        let decode = decode
        let gate = ChangeGate(initial: decode(store, key))
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            // `didChangeNotification` fires for *any* key in the suite; forward only on real changes.
            let newValue = decode(store, key)
            guard gate.isChange(newValue) else { return }
            subscriber.yield(newValue)
        }
        return SharedSubscription {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func save(_ value: Value, context _: SaveContext, continuation: SaveContinuation) {
        guard let key = resolvedKey else {
            // No logged-in user: nothing to persist against. Treat as a no-op success.
            continuation.resume()
            return
        }
        encode(value, store.wrappedValue, key)
        continuation.resume()
    }

    // MARK: - Synchronous access

    /// Reads the current per-user value synchronously, or `valueWhenNoUser` if no user was logged
    /// in when the key was constructed.
    public func currentValue() -> Value {
        guard let key = resolvedKey else { return valueWhenNoUser }
        return decode(store.wrappedValue, key)
    }

    /// Writes the per-user value synchronously. No-op when no user was logged in at construction.
    public func setCurrentValue(_ value: Value) {
        guard let key = resolvedKey else { return }
        encode(value, store.wrappedValue, key)
    }

    /// An `AsyncStream` of value changes. Emits the current value immediately, then re-reads on every `UserDefaults` change,
    /// suppressing consecutive duplicates so a write to an unrelated key in the suite doesn't produce a redundant emission.
    public func valuesStream() -> AsyncStream<Value> {
        let store = store.wrappedValue
        let resolvedKey = resolvedKey
        let valueWhenNoUser = valueWhenNoUser
        let decode = decode
        return AsyncStream { continuation in
            guard let key = resolvedKey else {
                continuation.yield(valueWhenNoUser)
                continuation.finish()
                return
            }
            let initial = decode(store, key)
            continuation.yield(initial)
            let gate = ChangeGate(initial: initial)
            let observer = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: store,
                queue: nil
            ) { _ in
                let newValue = decode(store, key)
                guard gate.isChange(newValue) else { return }
                continuation.yield(newValue)
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Like ``valuesStream()`` but maps each raw value through `transform` and suppresses consecutive duplicates
    /// `transform` typically re-derives the authorized/effective value, so it may ignore its input and read the clamped getter instead.
    public func mappedStream<T: Equatable & Sendable>(
        _ transform: @escaping @Sendable (Value) -> T
    ) -> AsyncStream<T> {
        let base = valuesStream()
        return AsyncStream<T> { continuation in
            let task = Task {
                var last: T?
                for await value in base {
                    let mapped = transform(value)
                    guard mapped != last else { continue }
                    last = mapped
                    continuation.yield(mapped)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Encodings

public extension UserScopedAppStorageKey {
    /// A per-user key for an optional `Codable` value, stored as JSON `Data`
    /// Absence of a stored value (or no logged-in user) reads as `nil`.
    static func json<Wrapped: Codable & Sendable>(
        _ baseKey: String,
        scope: UserScope = .username
    ) -> UserScopedAppStorageKey<Wrapped?> {
        UserScopedAppStorageKey<Wrapped?>(
            baseKey: baseKey,
            scope: scope,
            valueWhenNoUser: nil,
            decode: { store, key in
                guard let data = store.data(forKey: key) else {
                    return nil
                }
                do {
                    return try JSONDecoder().decode(Wrapped.self, from: data)
                } catch {
                    log.error("UserScopedAppStorageKey failed to decode value for key: \(key)", category: .persistence, metadata: ["error": "\(error)"])
                    return nil
                }
            },
            encode: { value, store, key in
                do {
                    if let value {
                        let data = try JSONEncoder().encode(value)
                        store.set(data, forKey: key)
                    } else {
                        store.removeObject(forKey: key)
                    }
                } catch {
                    log.error("UserScopedAppStorageKey failed to encode value for key: \(key)", category: .persistence, metadata: ["error": "\(error)"])
                }
            }
        )
    }

    /// A per-user key for an optional `RawRepresentable<Int>` value, stored as a native `Int`
    static func rawInt<Wrapped: RawRepresentable & Sendable>(
        _ baseKey: String
    ) -> UserScopedAppStorageKey<Wrapped?> where Wrapped.RawValue == Int {
        UserScopedAppStorageKey<Wrapped?>(
            baseKey: baseKey,
            valueWhenNoUser: nil,
            decode: { store, key in
                guard store.object(forKey: key) != nil else { return nil }
                return Wrapped(rawValue: store.integer(forKey: key))
            },
            encode: { value, store, key in
                if let value {
                    store.set(value.rawValue, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
            }
        )
    }

    /// A per-user key for an optional `Bool`, stored as a native `Bool`
    static func bool(
        _ baseKey: String
    ) -> UserScopedAppStorageKey<Bool?> {
        UserScopedAppStorageKey<Bool?>(
            baseKey: baseKey,
            valueWhenNoUser: nil,
            decode: { store, key in
                guard store.object(forKey: key) != nil else { return nil }
                return store.bool(forKey: key)
            },
            encode: { value, store, key in
                if let value {
                    store.set(value, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
            }
        )
    }

    /// A per-user key for an optional `String`, stored as a native `String`
    /// Absence of a stored value (or no logged-in user) reads as `nil`.
    static func string(
        _ baseKey: String
    ) -> UserScopedAppStorageKey<String?> {
        UserScopedAppStorageKey<String?>(
            baseKey: baseKey,
            valueWhenNoUser: nil,
            decode: { store, key in
                store.string(forKey: key)
            },
            encode: { value, store, key in
                if let value {
                    store.set(value, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
            }
        )
    }

    /// A per-user key for an optional `Date`, stored natively
    static func date(
        _ baseKey: String
    ) -> UserScopedAppStorageKey<Date?> {
        UserScopedAppStorageKey<Date?>(
            baseKey: baseKey,
            valueWhenNoUser: nil,
            decode: { store, key in
                store.object(forKey: key) as? Date
            },
            encode: { value, store, key in
                if let value {
                    store.set(value, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
            }
        )
    }
}
