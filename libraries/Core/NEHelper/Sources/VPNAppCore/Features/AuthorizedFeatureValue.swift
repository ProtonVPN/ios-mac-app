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

/// Reads and writes a `ProvidableFeature`'s value, decoupling *raw* storage from *authorized*
/// (effective) reads — the "raw vs effective" split.
///
/// - The raw user setting is stored per-user in `UserDefaults` (via ``UserScopedAppStorageKey``),
///   JSON-encoded under the feature's `storageKey`
/// - ``effectiveValue(userTier:featureFlags:)`` applies tier + feature-flag authorization on read,
///   returning the feature's default (or clamping) when the user is not authorized — reproducing
///   the previous `AppFeaturePropertyProviderImplementation.getValue` semantics, but as a separate
///   composable layer on top of raw storage.
///
/// - Important: The logged-in user and the `UserDefaults` suite are resolved once, at `init`.
///   Construct instances at the point of use (as ``featureValue(for:)`` / ``setFeatureValue(_:)``
///   do) rather than caching them in singletons or long-lived objects; a cached instance stays
///   pinned to the user and suite that were current when it was created.
public struct AuthorizedFeatureValue<Feature: ProvidableFeature & Sendable>: Sendable {
    private let rawKey: UserScopedAppStorageKey<Feature?>
    /// The suite legacy *global* (non user-scoped) values live in. Resolved once, alongside
    /// `rawKey`, so the per-user reads and the legacy read/delete always target the same suite.
    private let store: UncheckedSendable<UserDefaults>

    public init() {
        @Dependency(\.defaultAppStorage) var store
        self.rawKey = .json(Feature.storageKey)
        self.store = UncheckedSendable(store)
    }

    /// Identity of the underlying per-user storage location (resolved key + suite), for shared
    /// keys built on top of this type. Two instances with equal `id` read and write the same
    /// location for the same user.
    public var id: UserScopedAppStorageKey<Feature?>.ID {
        rawKey.id
    }

    // MARK: Raw storage (no authorization)

    /// The raw stored user value, or `nil` if none is stored (ignoring authorization).
    public func rawValue() -> Feature? {
        rawKey.currentValue()
    }

    /// Persists the raw user value (no authorization clamping).
    public func setValue(_ value: Feature) {
        rawKey.setCurrentValue(value)
    }

    /// A `SharedReader` over the raw stored value, for reactive observation (e.g. SwiftUI or
    /// `for await _ in $value.publisher.values`). Yields `nil` when no value is stored.
    public func sharedReader() -> SharedReader<Feature?> {
        SharedReader(rawKey)
    }

    // MARK: Effective (authorized) value

    /// The effective value the app should use, given the current `userTier` and `featureFlags`.
    ///
    /// Mirrors the legacy `getValue` logic:
    /// 1. If the feature is not authorized (static `canUse`), return the default.
    /// 2. If no raw value is stored, attempt a one-time legacy migration; otherwise return the default.
    /// 3. If the stored value itself is not authorized (instance `canUse`), return the default.
    /// 4. Otherwise return the stored value.
    public func effectiveValue(userTier: VpnTier, featureFlags: FeatureFlags) -> Feature {
        // The static authorization check runs *before* any storage access, matching the legacy
        // `getValue` ordering: an unauthorized feature must not trigger the (destructive,
        // read-and-delete) legacy migration in `storedValue()`.
        guard Feature.canUse(userTier: userTier, featureFlags: featureFlags).isAllowed else {
            return Feature.defaultValue(userTier: userTier, featureFlags: featureFlags)
        }
        return Self.clamp(storedValue(), userTier: userTier, featureFlags: featureFlags)
    }

    /// Convenience: reads the current `userTier` and `featureFlags` from shared storage and returns
    /// the effective value.
    public func value() -> Feature {
        @SharedReader(.userTier) var userTier: VpnTier?
        @SharedReader(.featureFlags) var featureFlags: FeatureFlags
        return effectiveValue(userTier: userTier ?? .free, featureFlags: featureFlags)
    }

    /// A stream of effective values: the current value immediately, then re-derived on every
    /// `UserDefaults` change (the signal `@Shared` app storage observes), suppressing consecutive
    /// duplicates so a write to an unrelated key in the suite doesn't produce a redundant emission.
    ///
    /// Everything the stream needs — the raw key, the tier and flag readers, the suite — is
    /// captured when the stream is created. The notification observer escapes the dependency scope
    /// this method is called in, so it must not construct shared keys or touch `@Dependency`
    /// itself. As a consequence the stream is pinned to the user current at creation; recreate it
    /// on a user switch.
    public func valueStream() -> AsyncStream<Feature> {
        // Created in the caller's scope; their references keep themselves current via their own
        // subscriptions, so reading `wrappedValue` inside the observer is dependency-free.
        @SharedReader(.userTier) var userTier: VpnTier?
        @SharedReader(.featureFlags) var featureFlags: FeatureFlags
        let tierReader = $userTier
        let flagsReader = $featureFlags
        let rawKey = rawKey
        let store = store.wrappedValue

        // The one-time legacy migration (if any) runs here, in the creation scope; the observer
        // below intentionally reads raw storage only.
        let initial = effectiveValue(userTier: userTier ?? .free, featureFlags: featureFlags)

        let readEffective: @Sendable () -> Feature = {
            Self.clamp(
                rawKey.currentValue(),
                userTier: tierReader.wrappedValue ?? .free,
                featureFlags: flagsReader.wrappedValue
            )
        }

        return AsyncStream { continuation in
            continuation.yield(initial)
            let gate = ChangeGate(initial: initial)
            let observer = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: store,
                queue: nil
            ) { _ in
                let newValue = readEffective()
                guard gate.isChange(newValue) else { return }
                continuation.yield(newValue)
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // MARK: Private

    /// The single source of the authorization rules: default when the feature (or the stored value
    /// itself) is not authorized, the stored value otherwise. Pure, so `effectiveValue` and the
    /// stream re-derivation cannot drift apart.
    private static func clamp(
        _ stored: Feature?,
        userTier: VpnTier,
        featureFlags: FeatureFlags
    ) -> Feature {
        let defaultValue = Feature.defaultValue(userTier: userTier, featureFlags: featureFlags)

        guard Feature.canUse(userTier: userTier, featureFlags: featureFlags).isAllowed else {
            return defaultValue
        }

        guard let stored else {
            return defaultValue
        }

        guard stored.canUse(userTier: userTier, featureFlags: featureFlags).isAllowed else {
            return defaultValue
        }

        return stored
    }

    /// Returns the user-specific raw value, falling back to a one-time migration of a legacy global
    /// value (for features that define a `legacyConversion`).
    private func storedValue() -> Feature? {
        if let value = rawValue() {
            return value
        }
        if let migrated = migrateLegacyGlobalValueIfNeeded() {
            setValue(migrated)
            return migrated
        }
        return nil
    }

    /// Reproduces `fetchAndDeleteStoredLegacyValue`: older app versions stored a *global* (non
    /// user-specific) value under `storageKey`, sometimes as a primitive `LegacyStorageType`. Read
    /// it once, delete it (so it doesn't act as a default for other users), and convert it.
    ///
    /// Runs only when the key is bound to a logged-in user: the migration is destructive
    /// (read-and-delete), and without a user the follow-up `setValue` is a no-op — the legacy
    /// value would be erased before it could ever be persisted for anyone.
    private func migrateLegacyGlobalValueIfNeeded() -> Feature? {
        guard rawKey.isBoundToUser, let conversion = Feature.legacyConversion else { return nil }
        let store = store.wrappedValue

        // Decodable value stored for the global setting.
        if let data = store.data(forKey: Feature.storageKey),
           let globalValue = try? JSONDecoder().decode(Feature.self, from: data) {
            store.removeObject(forKey: Feature.storageKey)
            return globalValue
        }

        // Primitive object stored for the global setting; try to cast to the legacy type.
        if let object = store.object(forKey: Feature.storageKey) {
            store.removeObject(forKey: Feature.storageKey)
            if let legacyValue = object as? Feature.LegacyStorageType {
                return conversion(legacyValue)
            }
        }

        return nil
    }
}

// MARK: - Convenience free functions

/// The effective (authorized) value for `feature`, reading the current user tier and feature flags
/// from shared storage. Convenience over `AuthorizedFeatureValue<Feature>().value()`.
public func featureValue<Feature: ProvidableFeature & Sendable>(for _: Feature.Type) -> Feature {
    AuthorizedFeatureValue<Feature>().value()
}

/// Persists the raw user value for a feature. Convenience over `AuthorizedFeatureValue<Feature>().setValue(_:)`.
public func setFeatureValue<Feature: ProvidableFeature & Sendable>(_ value: Feature) {
    AuthorizedFeatureValue<Feature>().setValue(value)
}
