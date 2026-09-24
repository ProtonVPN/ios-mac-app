//
//  Created on 02.09.2026.
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

import Combine
import ConcurrencyExtras
import Dependencies
@testable import Domain
import Foundation
import Sharing
import Testing

@Suite("MDMAppStorageKey")
struct MDMAppStorageKeyTests {
    private enum Keys {
        /// This `basic` key is just to be used for basic tests to ensure our helpers and translation functions are working.
        static let basic: String = "Basic"
        static let alwaysOn: String = "AlwaysOnEnabled"
        static let orgID: String = "OrganizationID"
        static let restrictLogins: String = "RestrictLogins"
    }
    
    // MARK: - mdmBool: Load
    
    @Test("mdmBool translator returns false when the key holds false, even if the default is true")
    func mdmBoolExplicitFalseOverridesDefault() {
        let setKey = Keys.basic
        
        withStore { defaults in
            defaults.set(false, forKey: setKey)
            @SharedReader(wrappedValue: true, makeBoolKey(setKey, default: true))
            var value: Bool
            #expect(value == false)
        }
    }
    
    /// Test for when backend contract doesn't align `AlwaysOnEnabled` as `<string>true</string>`
    /// (an XML plist string) instead of the native plist boolean `<true/>`.
    ///
    /// Even though we can't technically test this in our code with the backend's response, this is a good expectation to
    /// document through tests of what and how it is expected to behave.
    ///
    /// The `mdmBool` factory casts via `NSNumber`, which a bare `String` is not.
    /// The deliberate behavior is to fall back to `defaultValue` — we do **not** coerce
    /// strings to booleans.
    @Test("mdmBool falls back to default when a String is stored")
    func mdmBoolStringValueFallsBackToDefault() {
        let setKey = Keys.alwaysOn
        
        withStore { defaults in
            defaults.set("true", forKey: setKey)
            @SharedReader(wrappedValue: false, makeBoolKey(setKey, default: false))
            var value: Bool
            #expect(value == false)
        }
    }
    
    // MARK: - mdmBool: Subscription
    
    @Test("mdmBool subscription delivers the new value when the key changes")
    func mdmBoolSubscriptionFires() async {
        let defaults = UserDefaults.inMemory
        let setKey = Keys.basic
        
        await withDependencies {
            $0.defaultAppStorage = defaults
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                defaults.object(forKey: key)})
        } operation: {
            @SharedReader(wrappedValue: false, makeBoolKey(setKey))
            var value: Bool
            #expect(value == false)
            
            defaults.set(true, forKey: setKey)
            await Task.yield()
            #expect(value == true)
        }
    }
    
    @Test("mdmBool subscription does not emit for unchanged values (ChangeGate)")
    func mdmBoolSubscriptionDeduplicates() async {
        let defaults = UserDefaults.inMemory
        let duplicateKey = Keys.basic
        
        await withDependencies {
            $0.defaultAppStorage = defaults
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                defaults.object(forKey: key)})
        } operation: {
            // Set value to true in the store
            defaults.set(true, forKey: duplicateKey)
            // placeholder is false, load() should should resolve the value to be true
            @SharedReader(wrappedValue: false, makeBoolKey(duplicateKey))

            var value: Bool

            let received = LockIsolated<Int>(0)
            let cancellable = $value.publisher.sink { _ in received.withValue { $0 += 1 } }
            defer { cancellable.cancel() }
            
            #expect(received.value == 1)
            
            // Writing the same value should not produce an additional updates.
            defaults.set(true, forKey: duplicateKey)
            await Task.yield()
            #expect(received.value == 1)
            
            // Writing a different value must produce only one update.
            defaults.set(false, forKey: duplicateKey)
            await Task.yield()
            #expect(received.value == 2)
        }
    }
    
    /// This test verifies that writing an non related key does not cause an emission for `alwaysOnEnabled`.
    ///
    /// The subscription observer will run (the notification fires store-wide), but
    /// `ChangeGate` must suppress the delivery because the derived value for
    /// `alwaysOnEnabled` did not change.
    @Test("writing an unrelated key does not cause a alwaysOnEnabled to fire.")
    func unrelatedKeyChangeDoesNotEmit() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                defaults.object(forKey: key)})
        } operation: {
            // Value never set, it should default to the default
            @SharedReader(wrappedValue: false, makeBoolKey(Keys.alwaysOn))
            var value: Bool
            #expect(value == false)
            
            let received = LockIsolated<Int>(0)
            let cancellable = $value.publisher.sink { _ in received.withValue { $0 += 1 } }
            defer { cancellable.cancel() }
            
            // Account for the publishers current value on subscribers
            #expect(received.value == 1)
            
            // Write a completely different key in the same store.
            defaults.set("acme-corp", forKey: Keys.orgID)
            await Task.yield()
            
            // The derived value for AlwaysOnEnabled is still false.
            #expect(received.value == 1)
            #expect(value == false)
        }
    }
    
    /// Verifies that cancelling a `SharedSubscription` removes the underlying
    /// `NotificationCenter` observer.
    @Test("cancelling SharedSubscription removes the NotificationCenter observer")
    func subscriptionCancellationRemovesObserver() async {
        let defaults = UserDefaults.inMemory
        let cancelKey = Keys.basic
        
        let key = withDependencies {
            $0.defaultAppStorage = defaults
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                defaults.object(forKey: key)})
        } operation: {
            makeBoolKey(cancelKey)
        }
        
        let yieldCount = LockIsolated<Int>(0)
        let subscriber = SharedSubscriber<Bool>(callback: { _ in yieldCount.withValue { $0 += 1 }})
        let subscription = key.subscribe(context: .userInitiated, subscriber: subscriber)
        
        // Observer is active — writing a new value must trigger a yield.
        defaults.set(true, forKey: cancelKey)
        await Task.yield()
        #expect(yieldCount.value == 1)
        
        // Cancel: the NotificationCenter observer must be removed.
        subscription.cancel()
        
        // Writing again shouldn't create extra yields.
        defaults.set(false, forKey: cancelKey)
        await Task.yield()
        #expect(yieldCount.value == 1)
        
        // Confirm the value was actually written
        let finalRaw = defaults.object(forKey: cancelKey) as? NSNumber
        #expect(finalRaw?.boolValue == false)
    }
    
    // MARK: - mdmString: Load
    
    @Test("mdmString returns nil when the key is not present")
    func mdmStringAbsentKeyReturnsNil() {
        withStore { _ in
            @SharedReader(makeStringKey(Keys.basic)) var value: String?
            #expect(value == nil)
        }
    }

    @Test("mdmString returns nil when a non-string type is stored under the key")
    func mdmStringNonStringValueReturnsNil() {
        let setKey = Keys.orgID
        
        withStore { defaults in
            defaults.set(42, forKey: setKey)
            @SharedReader(makeStringKey(setKey)) var value: String?
            #expect(value == nil)
        }
    }
    
    @Test("mdmString subscription delivers the updated value when the key changes")
    func mdmStringSubscriptionFires() async {
        let defaults = UserDefaults.inMemory
        let setKey = Keys.orgID
        let setValue = "acme"
        
        await withDependencies {
            $0.defaultAppStorage = defaults
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                defaults.object(forKey: key)})
        } operation: {
            @SharedReader(makeStringKey(setKey)) var value: String?
            #expect(value == nil)
            
            defaults.set(setValue, forKey: setKey)
            await Task.yield()
            #expect(value == setValue)
        }
    }
    
    // MARK: - Key Identity
    
    /// `UserDefaults.inMemory` generates a UUID-based suite name on every call
    /// `storeA` and `storeB` below are separate `UserDefaults` instances with
    /// different `ObjectIdentifier`s.
    @Test("same named keys in different stores have distinct IDs")
    func sameNameDifferentStoresDifferentIDs() {
        let storeA = UserDefaults.inMemory
        let storeB = UserDefaults.inMemory
        let setKey = Keys.basic
        
        // Sanity-check: the two stores must not be the same object.
        #expect(ObjectIdentifier(storeA) != ObjectIdentifier(storeB))
        
        let keyA = withDependencies { $0.defaultAppStorage = storeA
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                storeA.object(forKey: key)})
        } operation: { makeBoolKey(setKey) }
        let keyB = withDependencies { $0.defaultAppStorage = storeB
            $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
                storeB.object(forKey: key)})
        } operation: { makeBoolKey(setKey) }
        
        #expect(keyA.id != keyB.id)
    }
    
    // MARK: - Platform Specific Reading
        
    #if os(tvOS)
    @Test("Do not read any keys if it is tvOS, we do not support")
    func tvOSNotSupported() {
        let appStorage = UserDefaults.inMemory
        let setKey = Keys.alwaysOn
        
        appStorage.set(true, forKey: setKey)
        #expect(appStorage.bool(forKey: setKey) == true)
        
        let value = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            ManagedDomainReader.liveValue.rawValue(setKey)
        }
        
        #expect(value == nil)
    }
    #endif
    
    #if os(macOS)
    @Test("Do not read un-managed keys for Mac even if their key is the same as the managed key")
    func macDoesNotReadUnManagedKeys() {
        let appStorage = UserDefaults.inMemory
        let setKey = Keys.alwaysOn
        
        appStorage.set(true, forKey: setKey)
        
        let value = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            ManagedDomainReader.liveValue.rawValue(setKey)
        }
    
        #expect(value == nil)
    }
    #endif

}

// MARK: - Helpers
private func makeBoolKey(_ key: String, default defaultValue: Bool = false) -> MDMAppStorageKey<Bool> {
    MDMAppStorageKey<Bool>(key: key) { raw in
        guard let number = raw as? NSNumber else { return defaultValue }
        return number.boolValue
    }
}

private func makeStringKey(_ key: String) -> MDMAppStorageKey<String?> {
    MDMAppStorageKey<String?>(key: key) { raw in raw as? String }
}

private func withStore<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
    let defaults = UserDefaults.inMemory
    return try withDependencies {
        $0.defaultAppStorage = defaults
        $0.managedDomainReader = ManagedDomainReader(rawValue: { key in
            defaults.object(forKey: key)
        })
    } operation: {
        try body(defaults)
    }
}
