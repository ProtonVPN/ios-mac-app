//
//  Created on 13/08/2026 by Max Kupetskyi.
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
import Testing
@testable import VPNAppCore
import VPNShared

struct AuthorizedFeatureValueMigrationTests {
    private static let username = "test-user"

    /// Runs `body` with a fresh in-memory suite and a keychain reporting `username` (pass `nil`
    /// for the logged-out state).
    private func withStorage<T>(
        username: String? = AuthorizedFeatureValueMigrationTests.username,
        _ body: (UserDefaults) throws -> T
    ) rethrows -> T {
        let defaults = UserDefaults.inMemory
        let keychain = MockAuthKeychain()
        if let username {
            keychain.setMockUsername(username)
        }
        return try withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            try body(defaults)
        }
    }

    private func perUserValue(in defaults: UserDefaults) -> MigratingFeature? {
        defaults.data(forKey: MigratingFeature.storageKey + Self.username)
            .flatMap { try? JSONDecoder().decode(MigratingFeature.self, from: $0) }
    }

    // MARK: - Happy paths

    @Test("Legacy global JSON value is served, persisted per-user, and deleted from the global key")
    func migratesLegacyGlobalJSONValue() throws {
        try withStorage { defaults in
            try defaults.set(JSONEncoder().encode(MigratingFeature.on), forKey: MigratingFeature.storageKey)

            let feature = AuthorizedFeatureValue<MigratingFeature>()
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .on)

            #expect(perUserValue(in: defaults) == .on, "Migrated value is persisted under the per-user key")
            #expect(defaults.object(forKey: MigratingFeature.storageKey) == nil, "Global value is deleted after migration")
        }
    }

    @Test("Legacy global primitive value goes through legacyConversion")
    func migratesLegacyPrimitiveValue() {
        withStorage { defaults in
            defaults.set(true, forKey: MigratingFeature.storageKey)

            let feature = AuthorizedFeatureValue<MigratingFeature>()
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .on)

            #expect(perUserValue(in: defaults) == .on)
            #expect(defaults.object(forKey: MigratingFeature.storageKey) == nil)
        }
    }

    @Test("Migration runs once: later global values are ignored once a per-user value exists")
    func migrationRunsOnce() throws {
        try withStorage { defaults in
            try defaults.set(JSONEncoder().encode(MigratingFeature.on), forKey: MigratingFeature.storageKey)

            let feature = AuthorizedFeatureValue<MigratingFeature>()
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .on)

            // A global value appearing after migration must be neither served nor deleted:
            // the per-user value now exists, so the migration path is never entered again.
            try defaults.set(JSONEncoder().encode(MigratingFeature.off), forKey: MigratingFeature.storageKey)
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .on)
            #expect(defaults.object(forKey: MigratingFeature.storageKey) != nil)
        }
    }

    @Test("A per-user value takes precedence over a lingering global value")
    func perUserValueWinsOverLegacy() throws {
        try withStorage { defaults in
            try defaults.set(JSONEncoder().encode(MigratingFeature.off), forKey: MigratingFeature.storageKey)

            let feature = AuthorizedFeatureValue<MigratingFeature>()
            feature.setValue(.on)

            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .on)
            #expect(defaults.object(forKey: MigratingFeature.storageKey) != nil, "Migration never ran, so the global value is untouched")
        }
    }

    // MARK: - Guards (the destructive delete must not run when the write can't land)

    @Test("Logged out: the legacy value is served as absent and left intact")
    func loggedOutLeavesLegacyValueIntact() throws {
        try withStorage(username: nil) { defaults in
            try defaults.set(JSONEncoder().encode(MigratingFeature.on), forKey: MigratingFeature.storageKey)

            let feature = AuthorizedFeatureValue<MigratingFeature>()
            // Without a user there is no per-user key to persist to, so the migration must not
            // run at all: deleting the global value here would lose it before any user could
            // inherit it (this pins the data-loss fix).
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .off, "Default: nothing readable is stored for 'no user'")
            #expect(defaults.object(forKey: MigratingFeature.storageKey) != nil, "Legacy value survives for the next logged-in user")
        }
    }

    @Test("Unauthorized feature: storage is not touched, so the legacy value survives")
    func unauthorizedFeatureDoesNotTriggerMigration() throws {
        try withStorage { defaults in
            try defaults.set(JSONEncoder().encode(GatedFeature.on), forKey: GatedFeature.storageKey)

            let feature = AuthorizedFeatureValue<GatedFeature>()
            // `GatedFeature.canUse` always fails: `effectiveValue` must short-circuit to the
            // default *before* reading storage, matching the legacy `getValue` ordering — an
            // unauthorized read is not allowed to consume the one-shot migration.
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .off)
            #expect(defaults.object(forKey: GatedFeature.storageKey) != nil)
        }
    }

    @Test("No legacyConversion (LegacyStorageType == Void): no migration is attempted")
    func noConversionMeansNoMigration() throws {
        try withStorage { defaults in
            try defaults.set(JSONEncoder().encode(UnmigratedFeature.on), forKey: UnmigratedFeature.storageKey)

            let feature = AuthorizedFeatureValue<UnmigratedFeature>()
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .off)
            #expect(defaults.object(forKey: UnmigratedFeature.storageKey) != nil, "Features without a conversion never touch the global key")
        }
    }

    // MARK: - Documented current behavior

    @Test("Corrupt legacy data is discarded on first touch")
    func corruptLegacyDataIsDiscarded() {
        withStorage { defaults in
            // Pins *current* behavior, mirroring the legacy `fetchAndDeleteStoredLegacyValue`:
            // undecodable global data is deleted on the first authorized, logged-in read (the
            // decode branch fails, the primitive branch removes the object, the cast fails).
            // If the policy ever changes to "preserve undecodable blobs", this test changes too.
            defaults.set(Data("not json".utf8), forKey: MigratingFeature.storageKey)

            let feature = AuthorizedFeatureValue<MigratingFeature>()
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .off)
            #expect(defaults.object(forKey: MigratingFeature.storageKey) == nil)
        }
    }
}

// MARK: - Fixtures

/// Migratable fixture: `LegacyStorageType = Bool` with a conversion, always authorized.
private enum MigratingFeature: Int, Codable, CaseIterable, Equatable, Sendable,
    AppFeature, DefaultableFeature, ModularAppFeature, StorableFeature {
    case off = 0
    case on = 1

    static var storageKey: String {
        "MigratingFeatureTestKey"
    }

    typealias LegacyStorageType = Bool
    static var legacyConversion: ((Bool) -> MigratingFeature)? {
        { $0 ? .on : .off }
    }

    static func defaultValue(userTier _: VpnTier, featureFlags _: FeatureFlags) -> MigratingFeature {
        .off
    }

    static func canUse(userTier _: VpnTier, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        .success
    }

    func canUse(userTier _: VpnTier, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        .success
    }
}

/// Fixture whose static authorization always fails — for verifying that unauthorized reads never
/// reach storage.
private enum GatedFeature: Int, Codable, CaseIterable, Equatable, Sendable,
    AppFeature, DefaultableFeature, ModularAppFeature, StorableFeature {
    case off = 0
    case on = 1

    static var storageKey: String {
        "GatedFeatureTestKey"
    }

    typealias LegacyStorageType = Bool
    static var legacyConversion: ((Bool) -> GatedFeature)? {
        { $0 ? .on : .off }
    }

    static func defaultValue(userTier _: VpnTier, featureFlags _: FeatureFlags) -> GatedFeature {
        .off
    }

    static func canUse(userTier _: VpnTier, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        .failure(.featureDisabled)
    }

    func canUse(userTier _: VpnTier, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        .failure(.featureDisabled)
    }
}

/// Fixture with the default `LegacyStorageType == Void` (no conversion) — migration must never
/// run for it.
private enum UnmigratedFeature: Int, Codable, CaseIterable, Equatable, Sendable,
    AppFeature, DefaultableFeature, ModularAppFeature, StorableFeature {
    case off = 0
    case on = 1

    static var storageKey: String {
        "UnmigratedFeatureTestKey"
    }

    static func defaultValue(userTier _: VpnTier, featureFlags _: FeatureFlags) -> UnmigratedFeature {
        .off
    }

    static func canUse(userTier _: VpnTier, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        .success
    }

    func canUse(userTier _: VpnTier, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        .success
    }
}
