//
//  Created on 18/03/2025.
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
import Ergonomics
@testable import CommonNetworking
@testable import HomeShared

@MainActor
final class SharedPropertiesFeatureTests: XCTestCase {

    func testFetchesLoadsOnIPChange() async {
        @Shared(.connectionState) var connectionState = .disconnected
        let loadsFetched = XCTestExpectation(description: "We should hit the API to fetch server loads")
        let loadsUpserted = XCTestExpectation(description: "We should update server loads in the database")

        let now = Date.now
        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            SharedPropertiesFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.logicalsClient.fetchLoads = { _ in
                loadsFetched.fulfill()
                return []
            }
            $0.serverRepository = .init(upsertLoads: { _ in loadsUpserted.fulfill() })
        }
        store.exhaustivity = .off

        await store.send(.listen)
        await store.receive(\.userLocation.delegate.userLocationChanged)
        await store.receive(\.refreshServerLoads)
        await fulfillment(of: [loadsFetched, loadsUpserted], timeout: 0, enforceOrder: true)
    }

    func testFetchesLocationOnDisconnection() async {
        @Shared(.connectionState) var connectionState = .disconnected

        let now = Date.now
        let clock = TestClock()
        let store = TestStore(initialState: .init()) {
            SharedPropertiesFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.logicalsClient.fetchLoads = { _ in return [] }
            $0.serverRepository = .init(upsertLoads: { _ in })
        }
        store.exhaustivity = .off

        await store.send(.listen)
        await store.send(.newConnectionState(.disconnected))
        await store.receive(\.userLocation.fetchUserLocation)
    }
}
