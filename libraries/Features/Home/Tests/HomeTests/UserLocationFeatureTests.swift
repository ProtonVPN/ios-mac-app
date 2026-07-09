//
//  Created on 19/03/2025.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Domain
import DomainTestSupport
import Ergonomics
import Foundation
@testable import HomeShared
import Testing

@MainActor
@Suite("User Location Feature Tests", .serialized)
struct UserLocationFeatureTests {
    @Test("Fetches location on launch")
    func fetchesLocationOnLaunch() async {
        @SharedReader(.connectionState) var connectionState = .disconnected

        let now = Date.now
        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .init(fetchLocation: { .poland })
        }

        await store.send(.listen)
        // TCA BUG: shared state DOES NOT change as a result of the next action, (can be confirmed through slapping
        // `_printChanges()` onto `UserLocationFeature`), but for some reason `TestStore` thinks it does.
        // If this test fails in the future, try removing this state assertion closure and uncommented the next one.
        await store.receive(\.fetchUserLocation) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.userLocationFetchStarted)
        // TCA BUG: the following action is where our expected shared state changes SHOULD be asserted.
        await store.receive(\.userLocationFetchFinished.success) // {
        //     $0.$userIP.withLock { $0 = UserLocation.poland.ip }
        //     $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
        //     $0.$lastLocationRetrieval.withLock { $0 = now }
        // }

        await store.receive(\.delegate.userLocationChanged)
        await store.send(.tearDown)
    }

    @Test("Fetches location on interval when disconnected")
    func fetchesLocationOnIntervalPassingWhenDisconnected() async {
        @SharedReader(.connectionState) var connectionState = .disconnected

        let now = Date.now
        let nextRefreshDate = now.addingTimeInterval(.hours(1))

        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .init(fetchLocation: { .poland })
        }

        await store.send(.listen)
        // TCA BUG: shared state DOES NOT change as a result of the next action, (can be confirmed through slapping
        // `_printChanges()` onto `UserLocationFeature`), but for some reason `TestStore` thinks it does.
        // If this test fails in the future, try removing this state assertion closure and uncommented the next one.
        await store.receive(\.fetchUserLocation) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.userLocationFetchStarted)

        // TCA BUG: the following action is where our expected shared state changes SHOULD be asserted.
        await store.receive(\.userLocationFetchFinished.success) // {
        //     $0.$userIP.withLock { $0 = UserLocation.poland.ip }
        //     $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
        //     $0.$lastLocationRetrieval.withLock { $0 = now }
        // }

        await store.receive(\.delegate.userLocationChanged)

        store.dependencies.date = .constant(nextRefreshDate)
        // Ensure the interval timer has registered its sleep with the clock before advancing (see
        // `awaitTimerSubscription`); otherwise the advance can race ahead of the timer's subscription.
        await clock.awaitTimerSubscription()
        await clock.advance(by: .hours(1))

        await store.receive(\.fetchUserLocation) {
            $0.$lastLocationRetrieval.withLock { $0 = nextRefreshDate }
        }
        await store.receive(\.userLocationFetchStarted)
        await store.receive(\.userLocationFetchFinished.success)
        await store.send(.tearDown)
    }

    @Test("Skips location fetch on interval when not disconnected")
    func skipsFetchingLocationOnIntervalPassingWhenNotDisconnected() async {
        @Shared(.connectionState) var connectionState = .disconnected

        let now = Date.now
        let nextRefreshDate = now.addingTimeInterval(.hours(1))

        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .init(fetchLocation: { .poland })
        }

        await store.send(.listen)
        // TCA BUG: shared state DOES NOT change as a result of the next action, (can be confirmed through slapping
        // `_printChanges()` onto `UserLocationFeature`), but for some reason `TestStore` thinks it does.
        // If this test fails in the future, try removing this state assertion closure and uncommented the next one.
        await store.receive(\.fetchUserLocation) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.userLocationFetchStarted)

        // TCA BUG: the following action is where our expected shared state changes SHOULD be asserted.
        await store.receive(\.userLocationFetchFinished.success) // {
        //     $0.$userIP.withLock { $0 = UserLocation.poland.ip }
        //     $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
        //     $0.$lastLocationRetrieval.withLock { $0 = now }
        // }

        await store.receive(\.delegate.userLocationChanged)

        $connectionState.withLock { $0 = .connecting(.unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all))) }
        store.dependencies.date = .constant(nextRefreshDate)
        // Ensure the interval timer has registered its sleep with the clock before advancing (see
        // `awaitTimerSubscription`); otherwise the advance can race ahead of the timer's subscription.
        await clock.awaitTimerSubscription()
        await clock.advance(by: .hours(1))

        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)
        await store.receive(\.userLocationFetchFinished.failure.incorrectVPNState)
        await store.send(.tearDown)
    }

    @Test("Does not fetch location more often than cooldown interval")
    func doesNotFetchLocationMoreOftenThanInterval() async {
        @Shared(.connectionState) var connectionState = .disconnected

        let now = Date.now
        let halfwayThroughRefreshInterval = now.addingTimeInterval(.minutes(30))

        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .init(fetchLocation: { .poland })
        }

        await store.send(.listen)
        // TCA BUG: shared state DOES NOT change as a result of the next action, (can be confirmed through slapping
        // `_printChanges()` onto `UserLocationFeature`), but for some reason `TestStore` thinks it does.
        // If this test fails in the future, try removing this state assertion closure and uncommented the next one.
        await store.receive(\.fetchUserLocation) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.userLocationFetchStarted)

        // TCA BUG: the following action is where our expected shared state changes SHOULD be asserted.
        await store.receive(\.userLocationFetchFinished.success) // {
        //     $0.$userIP.withLock { $0 = UserLocation.poland.ip }
        //     $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
        //     $0.$lastLocationRetrieval.withLock { $0 = now }
        // }

        await store.receive(\.delegate.userLocationChanged)

        $connectionState.withLock { $0 = .connecting(.unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all))) }
        store.dependencies.date = .constant(halfwayThroughRefreshInterval)
        await clock.advance(by: .minutes(30))

        await store.send(.didBecomeActive(notification: Notification(name: didBecomeActiveNotification)))
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchFinished.failure.cooldown)
        await store.send(.tearDown)
    }

    @Test("Unchanged location still refreshes cooldown")
    func unchangedLocationStillRefreshesCooldown() async {
        @SharedReader(.connectionState) var connectionState = .disconnected

        let now = Date.now
        let firstRefreshDate = now.addingTimeInterval(.hours(1))
        let halfwayPastFirstRefresh = now.addingTimeInterval(.minutes(90))

        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .init(fetchLocation: { .poland })
        }

        await store.send(.listen)
        await store.receive(\.fetchUserLocation) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }
        await store.receive(\.userLocationFetchStarted)
        await store.receive(\.userLocationFetchFinished.success)
        await store.receive(\.delegate.userLocationChanged)

        // Trigger a second fetch after one cooldown interval; location remains unchanged.
        store.dependencies.date = .constant(firstRefreshDate)
        // Ensure the interval timer has registered its sleep with the clock before advancing (see
        // `awaitTimerSubscription`); otherwise the advance can race ahead of the timer's subscription.
        await clock.awaitTimerSubscription()
        await clock.advance(by: .hours(1))
        await store.receive(\.fetchUserLocation) {
            $0.$lastLocationRetrieval.withLock { $0 = firstRefreshDate }
        }
        await store.receive(\.userLocationFetchStarted)
        await store.receive(\.userLocationFetchFinished.success)

        // A trigger only 30 minutes later should now respect cooldown.
        store.dependencies.date = .constant(halfwayPastFirstRefresh)
        await store.send(.didBecomeActive(notification: Notification(name: didBecomeActiveNotification)))
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchFinished.failure.cooldown)
        await store.send(.tearDown)
    }
}

private extension TestClock {
    /// Blocks until the clock has at least one registered suspension — i.e. the long-living
    /// `Effect.timer` started by `.listen` has reached its first `clock.sleep` and computed its tick
    /// deadline against the current `now`.
    ///
    /// `clock.advance(by:)` only `megaYield`s (a best-effort, fixed-count yield) before resolving
    /// suspensions, so on a contended cooperative pool — e.g. when another suite runs in parallel and
    /// toggles the global main-serial-executor that `TestStore` installs — the advance can run *before*
    /// the merged timer effect subscribes. Its first tick is then scheduled off the advanced `now`,
    /// never fires, and the test times out waiting for `.fetchUserLocation`. Draining the `.listen`
    /// effect chain via `receive` first makes that subscription likely but not guaranteed.
    ///
    /// `TestClock` exposes no blocking "await subscription" primitive, so we poll `checkSuspension()`,
    /// which throws `SuspensionError` once a sleeper is registered. The bound is only a safety net: in
    /// practice the timer is already subscribed and this returns on the first iteration.
    func awaitTimerSubscription() async {
        for _ in 0 ..< 100 {
            do {
                try await checkSuspension()
            } catch {
                return // a suspension is registered → timer subscribed → safe to advance
            }
        }
    }
}
