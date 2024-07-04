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
@testable import tvOS
@testable import CommonNetworking

final class AppFeatureTests: XCTestCase {
    @MainActor
    func testShowCreateAccount() async {
        let state = AppFeature.State()
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.welcome(.showCreateAccount)) {
            $0.welcome.destination = .welcomeInfo(.createAccount)
        }
    }

    @MainActor
    func testTabSelection() async {
        let state = AppFeature.State()
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.main(.selectTab(.settings))) { state in
            state.main.currentTab = .settings
        }
    }

    @MainActor
    func testOnAppear() async {
        let state = AppFeature.State()
        let alertService = AlertService.testValue
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.alertService = alertService
        }

        let task = await testOnAppearActions(store: store)

        await task.cancel()
    }

    @MainActor
    func testErrorAndAlertServiceHandling() async {
        enum CustomError: LocalizedError {
            case anExampleError

            var errorDescription: String? { "An example Error." }
            var failureReason: String? { "An explicit Error with no reason. It just fails!" }
        }

        let state = AppFeature.State()
        let alertService = AlertService.testValue
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.alertService = alertService
        }

        let error: CustomError = .anExampleError

        let task = await testOnAppearActions(store: store)

        await alertService.feed(error)

        await store.receive(\.incomingAlert) {
            $0.alert = AlertState(title: .init(error.errorDescription!), message: .init(error.failureReason!))
        }

        await task.cancel()
    }
}

private extension AppFeatureTests {
    @MainActor
    func testOnAppearActions(store: TestStoreOf<AppFeature>) async -> TestStoreTask {
        let task = await store.send(.onAppearTask)

        await store.receive(\.networking) { // startAcquiringSession
            $0.networking = .acquiringSession
        }
        await store.receive(\.networking) { // session fetched failure
            $0.networking = .unauthenticated(.network(internalError: ""))
        }

        return task
    }
}
