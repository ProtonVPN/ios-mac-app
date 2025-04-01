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

import XCTest
import ComposableArchitecture
import Domain
import DomainTestSupport
import Ergonomics
@testable import HomeShared

@MainActor
final class UserLocationFeatureTests: XCTestCase {

    func testFetchesLocationOnLaunch() async {
        @Shared(.connectionState) var connectionState = .disconnected

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

    func testFetchesLocationOnIntervalPassingWhenDisconnected() async {
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
        await clock.advance(by: .hours(1))

        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)
        await store.receive(\.userLocationFetchFinished.success)
        await store.send(.tearDown)
    }

    func testSkipsFetchingLocationOnIntervalPassingWhenNotDisconnected() async {
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

        $connectionState.withLock { $0 = .connecting(.unresolved(.init(spec: .defaultFastest, server: .mock))) }
        store.dependencies.date = .constant(nextRefreshDate)
        await clock.advance(by: .hours(1))

        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)
        await store.receive(\.userLocationFetchFinished.failure.incorrectVPNState)
        await store.send(.tearDown)
    }

    func testDoesNotFetchLocationMoreOftenThanInterval() async {
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

        $connectionState.withLock { $0 = .connecting(.unresolved(.init(spec: .defaultFastest, server: .mock))) }
        store.dependencies.date = .constant(halfwayThroughRefreshInterval)
        await clock.advance(by: .minutes(30))

        await store.send(.didBecomeActive(notification: Notification(name: didBecomeActiveNotification)))
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchFinished.failure.cooldown)
        await store.send(.tearDown)
    }
}
