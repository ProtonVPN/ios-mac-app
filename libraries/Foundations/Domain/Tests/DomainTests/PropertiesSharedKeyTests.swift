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

import Combine
import Dependencies
@testable import Domain
import Foundation
import Sharing
import Testing

/// Verifies the `@Shared` keys migrated off the legacy `PropertiesManager` read the same
/// UserDefaults representation the legacy properties used, and round-trip correctly.
@Suite(.serialized)
struct PropertiesSharedKeyTests {
    private func withStore<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
        // Unique suite per invocation: swift-sharing memoizes a store per suite *name*, so reusing a
        // name with a fresh `UserDefaults` object across tests trips its "new store object" check.
        let suiteName = "PropertiesSharedKeyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return try withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            try body(defaults)
        }
    }

    @Test("hasConnected defaults to false, reads the legacy ConnectOnDemand bool, round-trips")
    func hasConnected() {
        withStore { defaults in
            @Shared(.hasConnected) var hasConnected
            #expect(hasConnected == false)

            defaults.set(true, forKey: "ConnectOnDemand")
            #expect(hasConnected == true)

            $hasConnected.withLock { $0 = false }
            #expect(defaults.bool(forKey: "ConnectOnDemand") == false)
        }
    }

    @Test("showWhatsNewModal defaults to true")
    func showWhatsNewModal() {
        withStore { _ in
            @SharedReader(.showWhatsNewModal) var showWhatsNewModal
            #expect(showWhatsNewModal == true)
        }
    }

    @Test("maintenanceServerRefreshIntereval uses the domain default and reads a stored Int")
    func maintenanceInterval() {
        withStore { defaults in
            @SharedReader(.maintenanceServerRefreshIntereval) var interval
            #expect(interval == DomainConstants.Maintenance.defaultMaintenanceCheckTime)

            defaults.set(42, forKey: "MaintenanceServerRefreshIntereval")
            #expect(interval == 42)
        }
    }

    @Test("reportBugEmail round-trips and reads the legacy LastBugReportEmail string")
    func reportBugEmail() {
        withStore { defaults in
            @SharedReader(.reportBugEmail) var reportBugEmail
            #expect(reportBugEmail == nil)

            defaults.set("a@b.com", forKey: "LastBugReportEmail")
            #expect(reportBugEmail == "a@b.com")
        }
    }

    @Test("userLocation reads legacy JSON data and round-trips")
    func userLocation() throws {
        try withStore { defaults in
            let legacy = UserLocation(ip: "1.2.3.4", country: "PL", isp: "Play")
            try defaults.set(JSONEncoder().encode(legacy), forKey: "UserLocation")

            @Shared(.userLocation) var userLocation
            #expect(userLocation == legacy)

            $userLocation.withLock { $0 = nil }
            #expect(defaults.data(forKey: "UserLocation") == nil)
            #expect(userLocation == nil)
        }
    }

    @Test("featureFlagOverrides round-trips as JSON")
    func featureFlagOverrides() {
        withStore { _ in
            @Shared(.featureFlagOverrides) var overrides
            #expect(overrides == nil)

            $overrides.withLock { $0 = ["Flag": true] }
            #expect(overrides == ["Flag": true])
        }
    }

    @Test("userLocation publisher emits on change")
    func userLocationPublisher() async throws {
        let suiteName = "PropertiesSharedKeyTests-publisher"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        try await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.userLocation) var userLocation
            let expected = UserLocation(ip: "5.6.7.8", country: "US", isp: "AT&T")

            let received = LockIsolatedBox<[UserLocation?]>([])
            let cancellable = $userLocation.publisher.sink { received.value.append($0) }
            defer { cancellable.cancel() }

            $userLocation.withLock { $0 = expected }

            #expect(received.value.contains(expected))
        }
    }
}

/// Minimal thread-safe box for collecting publisher output in tests.
private final class LockIsolatedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value
    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
