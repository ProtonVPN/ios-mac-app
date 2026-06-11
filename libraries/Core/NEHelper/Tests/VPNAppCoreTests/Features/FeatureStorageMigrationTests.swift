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
import Testing
@testable import VPNAppCore
import VPNShared

@Suite(.serialized)
struct FeatureStorageMigrationTests {
    private static let username = "test-user"

    /// Runs `body` with a fresh, isolated `UserDefaults` suite as `defaultAppStorage` and a mock
    /// keychain reporting `username`, so per-user keys resolve to `key + username`.
    private func withFreshStorage<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
        let suiteName = "FeatureStorageMigrationTests-\(Self.username)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = MockAuthKeychain()
        keychain.setMockUsername(Self.username)
        return try withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            try body(defaults)
        }
    }

    @Test("Legacy JSON-encoded enum value is read transparently")
    func legacyJSONValueIsRead() throws {
        try withFreshStorage { defaults in
            // Legacy `Storage.setForUser` wrote `JSONEncoder().encode(value)` under `key + username`.
            let legacyData = try JSONEncoder().encode(VPNAccelerator.off)
            defaults.set(legacyData, forKey: "VpnAcceleratorEnabled" + Self.username)

            let key: UserScopedAppStorageKey<VPNAccelerator?> = .json("VpnAcceleratorEnabled")
            #expect(key.currentValue() == .off)
        }
    }

    @Test("Legacy raw-Int value (NetShield/NAT) is read transparently")
    func legacyRawIntValueIsRead() {
        withFreshStorage { defaults in
            // Legacy `UserDefaults.setUserValue(rawValue)` wrote a native Int under `key + username`.
            defaults.set(NetShieldType.level2.rawValue, forKey: "NetShield" + Self.username)

            let key: UserScopedAppStorageKey<NetShieldType?> = .rawInt("NetShield")
            #expect(key.currentValue() == .level2)
        }
    }

    @Test("Legacy native Bool value (PortForwarding) is read transparently")
    func legacyBoolValueIsRead() {
        withFreshStorage { defaults in
            defaults.set(false, forKey: "PortForwarding_" + Self.username)

            let key: UserScopedAppStorageKey<Bool?> = .bool("PortForwarding_")
            #expect(key.currentValue() == false)
        }
    }

    @Test("Absent value reads as nil")
    func absentValueIsNil() {
        withFreshStorage { _ in
            let key: UserScopedAppStorageKey<VPNAccelerator?> = .json("VpnAcceleratorEnabled")
            #expect(key.currentValue() == nil)
        }
    }

    @Test("Round-trips through the same per-user key")
    func roundTrips() {
        withFreshStorage { defaults in
            let key: UserScopedAppStorageKey<NetShieldType?> = .rawInt("NetShield")
            key.setCurrentValue(.level1)
            #expect(key.currentValue() == .level1)
            // Verify the on-disk representation matches the legacy native-Int format.
            #expect(defaults.object(forKey: "NetShield" + Self.username) as? Int == NetShieldType.level1.rawValue)
        }
    }

    @Test("effectiveValue returns the stored value when authorized")
    func effectiveValueAuthorized() {
        withFreshStorage { _ in
            let feature = AuthorizedFeatureValue<VPNAccelerator>()
            feature.setValue(.off)
            // Paid tier, flag on: `.off` is allowed, so the stored `.off` is returned.
            #expect(feature.effectiveValue(userTier: .paidTier, featureFlags: .allEnabled) == .off)
        }
    }

    @Test("effectiveValue clamps to default when the stored value is not authorized")
    func effectiveValueClamps() {
        withFreshStorage { _ in
            let feature = AuthorizedFeatureValue<VPNAccelerator>()
            feature.setValue(.off)
            // Free tier: `.off` requires upgrade, so the default `.on` is returned instead.
            #expect(feature.effectiveValue(userTier: .freeTier, featureFlags: .allEnabled) == .on)
        }
    }

    @Test("effectiveValue returns default when nothing is stored")
    func effectiveValueDefaultWhenAbsent() {
        withFreshStorage { _ in
            let feature = AuthorizedFeatureValue<VPNAccelerator>()
            #expect(feature.effectiveValue(userTier: .paidTier, featureFlags: .allEnabled) == .on)
        }
    }
}
