//
//  Created on 30/04/2024.
//
//  Copyright (c) 2024 Proton AG
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
@testable import CommonNetworking
@testable import tvOS
import tvOSTestSupport

final class HomeLoadingFeatureTests: XCTestCase {

    @MainActor
    func testFinishedLoadingSuccess() async {
        let store = TestStore(initialState: HomeLoadingFeature.State.loading) {
            HomeLoadingFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }
        await store.send(.finishedLoading(.success(Void()))) {
            $0 = .loaded(.init())
        }
    }

    @MainActor
    func testFinishedLoadingFailure() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeLoadingFeature.State.loading) {
            HomeLoadingFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        await store.send(.finishedLoading(.failure(""))) {
            $0 = .loadingFailed
        }
        await clock.advance(by: HomeLoadingFeature.tryAgainPeriod)
        await store.receive(\.startLoading) {
            $0 = .loading
        }
    }

    @MainActor
    func testFailedLoadingAfterOnAppearWithEmptyRepository() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeLoadingFeature.State.loading) {
            HomeLoadingFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
            $0.logicalsRefresher = LogicalsRefresher(
                refreshLogicals: { throw "" },
                shouldRefreshLogicals: { true })
            $0.date = .constant(.distantFuture) // logicalsRefresher
            $0.continuousClock = clock
            $0.logicalsClient = LogicalsClient(fetchLogicals: { _ in
                throw ""
            })
        }
        await store.send(.loadingViewOnAppear)
        await store.receive(\.finishedLoading) {
            $0 = .loadingFailed
        }
        await clock.advance(by: HomeLoadingFeature.tryAgainPeriod)
        await store.receive(\.startLoading) {
            $0 = .loading
        }
    }

    @MainActor
    func testFinishedLoadingAfterOnAppearWithNotEmptyRepository() async {
        let store = TestStore(initialState: HomeLoadingFeature.State.loading) {
            HomeLoadingFeature()
        } withDependencies: {
            $0.serverRepository = .notEmpty()
            $0.logicalsRefresher = LogicalsRefresher(
                refreshLogicals: {},
                shouldRefreshLogicals: { false })
        }
        await store.send(.loadingViewOnAppear)
        await store.receive(\.finishedLoading) {
            $0 = .loaded(.init())
        }
    }

    @MainActor
    func testStartLoading() async {
        let store = TestStore(initialState: HomeLoadingFeature.State.loadingFailed) {
            HomeLoadingFeature()
        }
        await store.send(.startLoading) {
            $0 = .loading
        }
    }
}
