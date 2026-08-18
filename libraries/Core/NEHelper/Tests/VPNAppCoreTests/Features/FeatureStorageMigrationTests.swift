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

import ConcurrencyExtras
import Dependencies
import Domain
import Foundation
import Sharing
import Testing
@testable import VPNAppCore
import VPNShared

struct FeatureStorageMigrationTests {
    private static let username = "test-user"

    /// Runs `body` with a fresh, isolated `UserDefaults` suite as `defaultAppStorage` and a mock
    /// keychain reporting `username`, so per-user keys resolve to `key + username`.
    private func withFreshStorage<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
        let defaults = UserDefaults.inMemory
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
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .off)
        }
    }

    @Test("effectiveValue clamps to default when the stored value is not authorized")
    func effectiveValueClamps() {
        withFreshStorage { _ in
            let feature = AuthorizedFeatureValue<VPNAccelerator>()
            feature.setValue(.off)
            // Free tier: `.off` requires upgrade, so the default `.on` is returned instead.
            #expect(feature.effectiveValue(userTier: .free, featureFlags: .allEnabled) == .on)
        }
    }

    @Test("effectiveValue returns default when nothing is stored")
    func effectiveValueDefaultWhenAbsent() {
        withFreshStorage { _ in
            let feature = AuthorizedFeatureValue<VPNAccelerator>()
            #expect(feature.effectiveValue(userTier: .paid, featureFlags: .allEnabled) == .on)
        }
    }

    @Test("valuesStream suppresses duplicate and unrelated-key writes")
    func valuesStreamSuppressesRedundantEmissions() async {
        let defaults = UserDefaults.inMemory
        let keychain = MockAuthKeychain()
        keychain.setMockUsername(Self.username)

        await withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            let key: UserScopedAppStorageKey<NetShieldType?> = .rawInt("NetShield")
            key.setCurrentValue(.level1)

            var iterator = key.valuesStream().makeAsyncIterator()

            // The current value is emitted immediately on subscription.
            #expect(await iterator.next() == .level1)

            // A re-write of the same value and a write to an unrelated key in the suite both fire
            // `didChangeNotification` but must NOT emit; the next value the stream produces should be
            // the genuinely-changed one. (If the gate is broken, `next()` will return a stale
            // `.level1` here instead.) Deterministic because `didChangeNotification` is delivered
            // synchronously on the writing thread, so all three writes are fully processed —
            // gated or buffered — before `next()` is awaited.
            key.setCurrentValue(.level1)
            defaults.set("unrelated", forKey: "SomeOtherKey")
            key.setCurrentValue(.level2)

            #expect(await iterator.next() == .level2)
        }
    }

    private struct PlanChangeSpies {
        let nat = LockIsolated<[NATType]>([])
        let netShield = LockIsolated<[NetShieldType]>([])
        let portForwarding = LockIsolated<[Bool?]>([])

        // NB: only the setters are replaced; the copied providers' getters/streams still share the
        // `CurrentValueSubject` captured by the static `testValue`s, so they must not be exercised
        // here until those `testValue`s become computed properties.
        func install(_ values: inout DependencyValues) {
            var natProvider = NATTypePropertyProvider.testValue
            natProvider.setNATType = { value in nat.withValue { $0.append(value) } }
            var netShieldProvider = NetShieldPropertyProvider.testValue
            netShieldProvider.setNetShieldType = { value in netShield.withValue { $0.append(value) } }
            var portForwardingProvider = PortForwardingPropertyProvider.testValue
            portForwardingProvider.setPortForwarding = { value in portForwarding.withValue { $0.append(value) } }
            values.natTypePropertyProvider = natProvider
            values.netShieldPropertyProvider = netShieldProvider
            values.portForwardingPropertyProvider = portForwardingProvider
        }
    }

    @Test("Plan downgrade to free turns paid features off and disables Secure Core")
    func planDowngradeResetsFeatures() {
        let spies = PlanChangeSpies()
        let defaults = UserDefaults.inMemory
        defaults.set(true, forKey: "secureCoreToggle")

        withDependencies {
            spies.install(&$0)
            $0.defaultAppStorage = defaults
        } operation: {
            applyPlanChangeFeatureResets(PlanChange(oldTier: .paid, newTier: .free))
        }

        #expect(spies.nat.withValue { $0 } == [.default])
        #expect(spies.netShield.withValue { $0 } == [.off])
        #expect(spies.portForwarding.withValue { $0 } == [false])
        #expect(defaults.bool(forKey: "secureCoreToggle") == false)
    }

    @Test("Plan upgrade from free enables NetShield and leaves other features untouched")
    func planUpgradeEnablesNetShield() {
        let spies = PlanChangeSpies()
        let defaults = UserDefaults.inMemory
        defaults.set(true, forKey: "secureCoreToggle")

        withDependencies {
            spies.install(&$0)
            $0.defaultAppStorage = defaults
        } operation: {
            applyPlanChangeFeatureResets(PlanChange(oldTier: .free, newTier: .paid))
        }

        #expect(spies.netShield.withValue { $0 } == [.level2])
        #expect(spies.nat.withValue { $0 }.isEmpty)
        #expect(spies.portForwarding.withValue { $0 }.isEmpty)
        // Secure Core is only reset on downgrade — an upgrade must leave it untouched.
        #expect(defaults.bool(forKey: "secureCoreToggle") == true)
    }

    @Test("ChangeGate dedupes nil -> nil for Optional values")
    func changeGateHandlesOptionalNil() {
        let gate = ChangeGate<Bool?>(initial: nil)
        #expect(gate.isChange(nil) == false) // nil -> nil: not a change
        #expect(gate.isChange(true) == true) // nil -> some: change
        #expect(gate.isChange(true) == false) // some -> same some: not a change
        #expect(gate.isChange(nil) == true) // some -> nil: change
        #expect(gate.isChange(nil) == false) // nil -> nil: not a change
    }

    @Test("ChangeGate dedupes equal non-optional values")
    func changeGateHandlesNonOptional() {
        let gate = ChangeGate<NATType>(initial: .strictNAT)
        #expect(gate.isChange(.strictNAT) == false)
        #expect(gate.isChange(.moderateNAT) == true)
    }
}
