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

@testable import CommonNetworking
import ComposableArchitecture
import Ergonomics
import ModalsServices
@testable import tvos_app
import XCTest

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

        await store.send(.main(.selectTab(.settings))) {
            $0.main.currentTab = .settings
            $0.main.$mainBackground.withLock { $0 = .clear }
        }
        await store.receive(\.main.settings.tabSelected)
    }

    @MainActor
    func testAcquiresSessionOnAppear() async {
        let state = AppFeature.State(networking: .unauthenticated(nil))
        let alertService = AlertService.testValue
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.alertService = alertService
        }

        store.exhaustivity = .off

        await store.send(.onAppearTask)

        await store.receive(\.networking.startAcquiringSession) {
            $0.networking = .acquiringSession
        }
        await store.receive(\.networking.sessionFetched.failure) {
            $0.networking = .unauthenticated(.network(internalError: "" as GenericError))
        }
    }

    @MainActor
    func testErrorAndAlertServiceHandling() async {
        enum CustomError: LocalizedError {
            case anExampleError

            var errorDescription: String? { "An example Error." }
            var failureReason: String? { "An explicit Error with no reason. It just fails!" }
        }

        let state = AppFeature.State(networking: .unauthenticated(nil))
        let alertService = AlertService.testValue
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.alertService = alertService
        }

        store.exhaustivity = .off

        let error: CustomError = .anExampleError

        await store.send(.onAppearTask)

        await alertService.feed(error)
        await store.receive(\.incomingAlert) {
            $0.alert = AlertState(title: .init(error.failureReason!), message: .init(error.errorDescription!))
        }
    }

    @MainActor
    func testUpsellDismissedWhenUpsellFlowCompleted() async {
        let state = AppFeature.State(
            welcome: .init(destination: .upsell(.loaded(planOptions: [], purchaseInProgress: true))),
            networking: .authenticated(.auth(uid: "userid"))
        )

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.welcome(.onAppear))

        await store.receive(\.welcome.userTierUpdated)

        await store.send(.upsell(.upsold(tier: 2))) {
            $0.$userTier.withLock { $0 = 2 }
        }

        await store.receive(\.welcome.userTierUpdated) {
            $0.welcome.destination = nil
        }
    }
}
