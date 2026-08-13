//
//  Created on 30/07/2026 by Max Kupetskyi.
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

import Clocks
import ComposableArchitecture
@testable import Connection
import Domain
import Foundation
import Sharing
import Testing
import VPNAppCore

@Suite("Maintenance polling")
struct MaintenanceFeatureTests {
    private static let intervalMinutes = 10
    private static let interval = Duration.seconds(intervalMinutes * 60)

    /// The interval is jittered by ±10%, so these tests advance the clock in windows that hold exactly one tick
    /// whatever the jitter turned out to be, rather than reproducing the jitter calculation.
    private static let longestInterval = interval * 1.1
    private static let tooShortToTick = interval * 0.5
    private static let restOfLongestInterval = longestInterval - tooShortToTick

    // MARK: - Polling

    @Test("Polls the server on the configured interval once started")
    @MainActor
    func pollsOnConfiguredInterval() async {
        let context = TestContext()
        let store = context.store()

        await store.send(.onStart)
        await store.receive(\.configurationChanged) { $0.pollingInterval = Self.interval }

        await context.clock.advance(by: Self.longestInterval)
        await store.receive(\.checkServer)

        await context.clock.advance(by: Self.longestInterval)
        await store.receive(\.checkServer)

        await store.send(.onStop) { $0.pollingInterval = nil }
    }

    @Test("Does not restart the countdown when the configuration is unchanged")
    @MainActor
    func keepsCountdownAcrossUnchangedConfiguration() async {
        let context = TestContext()
        let store = context.store()

        await store.send(.onStart)
        await store.receive(\.configurationChanged) { $0.pollingInterval = Self.interval }

        // Part way to the next check, then a feature flag refresh that changes nothing
        await context.clock.advance(by: Self.tooShortToTick)
        await store.send(.configurationChanged)

        // The countdown was not reset, so the check still lands within the original interval.
        // Had it restarted, the next tick could not arrive before another full interval.
        await context.clock.advance(by: Self.restOfLongestInterval)
        await store.receive(\.checkServer)

        await store.send(.onStop) { $0.pollingInterval = nil }
    }

    @Test("Stops polling when the server refresh feature flag is off")
    @MainActor
    func stopsPollingWhenFeatureFlagIsOff() async {
        let context = TestContext(featureFlags: .allDisabled)
        let store = context.store()

        await store.send(.onStart)
        await store.receive(\.configurationChanged)

        // Well past several intervals, with no check scheduled
        await context.clock.advance(by: Self.longestInterval * 3)

        await store.send(.onStop)
    }

    @Test("Checks once without scheduling when the interval is not positive")
    @MainActor
    func checksOnceWhenIntervalIsNotPositive() async {
        let context = TestContext(intervalMinutes: 0)
        let store = context.store()

        await store.send(.onStart)
        await store.receive(\.configurationChanged)
        await store.receive(\.checkServer)

        await context.clock.advance(by: Self.longestInterval * 3)

        await store.send(.onStop)
    }

    // MARK: - Reacting to maintenance

    @Test("Notifies and reconnects the first time a server goes into maintenance")
    @MainActor
    func notifiesAndReconnects() async {
        let context = TestContext(isUnderMaintenance: true)
        let store = context.store()

        await store.send(.checkServer)
        await store.receive(\.serverIsGoingIntoMaintenance) {
            $0.lastNotifiedAt = context.now
        }

        #expect(context.notificationCount.value == 1)
        #expect(context.reconnectCount.value == 1)
    }

    @Test("Throttles repeat notifications but reconnects every time")
    @MainActor
    func throttlesNotificationsButAlwaysReconnects() async {
        let context = TestContext(isUnderMaintenance: true)
        let store = context.store()

        await store.send(.checkServer)
        await store.receive(\.serverIsGoingIntoMaintenance) { $0.lastNotifiedAt = context.now }

        // A second detection inside the throttle window
        await store.send(.checkServer)
        await store.receive(\.serverIsGoingIntoMaintenance)

        #expect(context.notificationCount.value == 1)
        #expect(context.reconnectCount.value == 2)
    }

    @Test("Does nothing when the connected server is healthy")
    @MainActor
    func ignoresHealthyServer() async {
        let context = TestContext(isUnderMaintenance: false)
        let store = context.store()

        await store.send(.checkServer)

        #expect(context.notificationCount.value == 0)
        #expect(context.reconnectCount.value == 0)
    }
}

// MARK: - Helpers

/// Wires up the shared configuration and the collaborators the feature reaches for.
private final class TestContext {
    let clock = TestClock()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let notificationCount = Counter()
    let reconnectCount = Counter()

    private let defaults: UserDefaults
    private let featureFlags: FeatureFlags
    private let isUnderMaintenance: Bool

    init(
        intervalMinutes: Int = 10,
        featureFlags: FeatureFlags = .allEnabled,
        isUnderMaintenance: Bool = false
    ) {
        // Fresh in-memory suite per instance
        self.defaults = UserDefaults.inMemory
        // Seeded before any shared reference exists, so the feature reads it through `load` —
        // and under the legacy (misspelled, load-bearing) key.
        defaults.set(intervalMinutes, forKey: "MaintenanceServerRefreshIntereval")
        self.featureFlags = featureFlags
        self.isUnderMaintenance = isUnderMaintenance
    }

    @MainActor
    func store() -> TestStoreOf<MaintenanceFeature> {
        // `defaultAppStorage` is set twice on purpose: the outer scope is what the seeding
        // `@Shared(.featureFlags)` below resolves against; the inner one is what the TestStore
        // hands the reducer. Both must point at this context's suite so the seeded reference and
        // the reducer's references share an identity.
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.featureFlags) var storedFeatureFlags
            $storedFeatureFlags.withLock { $0 = featureFlags }

            return TestStore(initialState: MaintenanceFeature.State()) {
                MaintenanceFeature()
            } withDependencies: {
                $0.defaultAppStorage = defaults
                $0.continuousClock = clock
                $0.date = .constant(now)
                $0.withRandomNumberGenerator = WithRandomNumberGenerator(SystemRandomNumberGenerator())
                $0.maintenanceChecker.isCurrentServerUnderMaintenance = { [isUnderMaintenance] in
                    isUnderMaintenance
                }
                $0.notificationManager.displayServerGoingOnMaintenance = { [notificationCount] in
                    notificationCount.increment()
                }
                $0.connectionCommandClient.quickConnect = { [reconnectCount] _ in
                    reconnectCount.increment()
                }
            }
        }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
