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
import Foundation
import Sharing
import VPNShared

/// A `SharedKey` that persists a value in `UserDefaults` under a *per-user* key.
///
/// The on-disk key is `baseKey + username`, where `username` is resolved dynamically from
/// `authKeychain` on every load/save — exactly mirroring the legacy `Storage.setForUser` /
/// `UserDefaults.setUserValue` behaviour (`key + username`, no separator). This guarantees that
/// values written by previous app versions are read transparently, with no migration step.
///
/// The underlying `UserDefaults` suite is the one configured for swift-sharing
/// (`\.defaultAppStorage`), which on iOS is the shared app-group suite and on macOS is
/// `.standard` — the same suite the legacy storage targeted.
///
/// The key's identity is *feature-scoped* (the `baseKey`, not the resolved per-user key), matching
/// the previous `FeatureSharedKey`. The per-user value is resolved on each access, so a change of
/// logged-in user is reflected on the next load.
/// Which authenticated-user identifier a ``UserScopedAppStorageKey``'s on-disk key is scoped to.
public enum UserScope: Sendable {
    /// `baseKey + authKeychain.username` — the default
    case username
    /// `baseKey + authKeychain.userId`
    case userId
}

public final class UserScopedAppStorageKey<Value: Sendable>: SharedKey {
    private let baseKey: String
    private let scope: UserScope
    private let valueWhenNoUser: Value
    private let decode: @Sendable (UserDefaults, String) -> Value
    private let encode: @Sendable (Value, UserDefaults, String) -> Void

    public var id: some Hashable {
        baseKey
    }

    init(
        baseKey: String,
        scope: UserScope = .username,
        valueWhenNoUser: Value,
        decode: @escaping @Sendable (UserDefaults, String) -> Value,
        encode: @escaping @Sendable (Value, UserDefaults, String) -> Void
    ) {
        self.baseKey = baseKey
        self.scope = scope
        self.valueWhenNoUser = valueWhenNoUser
        self.decode = decode
        self.encode = encode
    }

    private func resolvedKey() -> String? {
        @Dependency(\.authKeychain) var authKeychain
        let identifier: String? = switch scope {
        case .username:
            authKeychain.username
        case .userId:
            authKeychain.userId
        }
        guard let identifier else { return nil }
        return baseKey + identifier
    }

    public func load(context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        @Dependency(\.defaultAppStorage) var store
        guard let key = resolvedKey() else {
            continuation.resume(returning: valueWhenNoUser)
            return
        }
        continuation.resume(returning: decode(store, key))
    }

    public func subscribe(
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        @Dependency(\.defaultAppStorage) var store
        let gate = ChangeGate(initial: currentValue())
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: store,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            // `didChangeNotification` fires for *any* key in the suite; forward only on real changes.
            let newValue = currentValue()
            guard gate.isChange(newValue) else { return }
            subscriber.yield(newValue)
        }
        return SharedSubscription {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func save(_ value: Value, context _: SaveContext, continuation: SaveContinuation) {
        guard let key = resolvedKey() else {
            // No logged-in user: nothing to persist against. Treat as a no-op success.
            continuation.resume()
            return
        }
        @Dependency(\.defaultAppStorage) var store
        encode(value, store, key)
        continuation.resume()
    }

    // MARK: - Synchronous access

    /// Reads the current per-user value synchronously (resolving the username at call time), or
    /// `valueWhenNoUser` if there is no logged-in user.
    public func currentValue() -> Value {
        guard let key = resolvedKey() else { return valueWhenNoUser }
        @Dependency(\.defaultAppStorage) var store
        return decode(store, key)
    }

    /// Writes the per-user value synchronously (resolving the username at call time). No-op when
    /// there is no logged-in user.
    public func setCurrentValue(_ value: Value) {
        guard let key = resolvedKey() else { return }
        @Dependency(\.defaultAppStorage) var store
        encode(value, store, key)
    }

    /// An `AsyncStream` of value changes, replacing the per-provider `CurrentValueSubject`s. Emits
    /// the current value immediately, then re-reads on every `UserDefaults` change (the same signal
    /// `@Shared` app storage observes), suppressing consecutive duplicates so a write to an
    /// unrelated key in the suite doesn't produce a redundant emission.
    public func valuesStream() -> AsyncStream<Value> {
        @Dependency(\.defaultAppStorage) var store
        return AsyncStream { continuation in
            let initial = currentValue()
            continuation.yield(initial)
            let gate = ChangeGate(initial: initial)
            let observer = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: store,
                queue: nil
            ) { [weak self] _ in
                guard let self else { return }
                let newValue = currentValue()
                guard gate.isChange(newValue) else { return }
                continuation.yield(newValue)
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Like ``valuesStream()`` but maps each raw value through `transform` and suppresses
    /// consecutive duplicates — the equivalent of the previous `CurrentValueSubject` +
    /// `removeDuplicates()` streams. `transform` typically re-derives the authorized/effective
    /// value, so it may ignore its input and read the clamped getter instead.
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

    /// A per-user key for an optional `Bool`, stored as a native `Bool
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
