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
@testable import Connection
@testable import CoreConnection
import Ergonomics
@testable import ExtensionManager
import ModalsServices
@testable import tvos_app
import XCTest

final class AppFeatureTests: XCTestCase {
    @MainActor
    func testShowCreateAccount() async {
        let state = AppFeature.State(screen: .welcome(.init()))
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.screen(.welcome(.showCreateAccount))) {
            $0.screen = .welcome(.init(destination: .welcomeInfo(.createAccount)))
        }
    }

    @MainActor
    func testTabSelection() async {
        let state = AppFeature.State(screen: .main(.init()))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.screen(.main(.selectTab(.settings)))) {
            guard case let .main(mainState) = $0.screen else {
                XCTFail("Expected main screen")
                return
            }
            var updatedMainState = mainState
            updatedMainState.currentTab = .settings
            updatedMainState.$mainBackground.withLock { $0 = .clear }
            $0.screen = .main(updatedMainState)
        }
        await store.receive(\.screen.main.settings.tabSelected)
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
            $0.paymentsClient.startObserving = { .never }
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

        let state = AppFeature.State(networking: .authenticated(.auth(uid: "sessionID")))
        let alertService = AlertService.testValue
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.alertService = alertService
            $0.paymentsClient.startObserving = { .never }
        }

        store.exhaustivity = .off

        let error: CustomError = .anExampleError

        await store.send(.onAppearTask)

        await alertService.feed(error)
        await store.receive(\.incomingAlert) {
            $0.alert = AlertState(title: { .init(error.failureReason!) }, message: { .init(error.errorDescription!) })
        }
    }

    @MainActor
    func testErrorConnectingNotifiesError() async {
        // needed to be like this because CountryListItem has dependency in init
        let state = withDependencies {
            $0.serverRepository = .empty()
        } operation: {
            AppFeature.State(
                screen: .main(.init(homeLoading: .loaded(.init()))),
                networking: .authenticated(.auth(uid: "sessionID"))
            )
        }
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.connection(.delegate(.connectionFailed(.serverMissing))))
        await store.receive(\.errorOccurred)
    }

    @MainActor
    func testRetryConnectionStartsSessionAcquisition() async {
        let state = AppFeature.State(networking: .unauthenticated(.network(internalError: "" as GenericError)))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
        }

        await store.send(.networking(.sessionFetched(.failure("" as GenericError)))) {
            $0.screen = .welcome(.init())
            $0.shouldPresentNetworkFailureAlert = true
            $0.alert = AppFeature.networkRequestFailedAlert
        }

        await store.send(.alert(.presented(.retryConnection))) {
            $0.shouldPresentNetworkFailureAlert = false
            $0.alert = nil
        }
        await store.receive(\.networking.startAcquiringSession) {
            $0.screen = .loading(.init())
            $0.networking = .acquiringSession
        }
        await store.receive(\.networking.sessionFetched.failure) {
            $0.screen = .welcome(.init())
            $0.networking = .unauthenticated(.network(internalError: "" as GenericError))
            $0.shouldPresentNetworkFailureAlert = true
            $0.alert = AppFeature.networkRequestFailedAlert
        }
    }

    @MainActor
    func testGetApplicationLogsFromNetworkFailureAlert() async {
        let state = AppFeature.State(networking: .unauthenticated(.network(internalError: "" as GenericError)))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.networking(.sessionFetched(.failure("" as GenericError)))) {
            $0.screen = .welcome(.init())
            $0.alert = AppFeature.networkRequestFailedAlert
            $0.shouldPresentNetworkFailureAlert = true
        }
        await store.send(.alert(.presented(.getApplicationLogs))) {
            $0.alert = nil
        }
        await store.receive(\.screen.welcome.showApplicationLogs) {
            $0.screen = .welcome(.init(destination: .logs(.init(logSource: .app))))
        }
        await store.send(.screen(.welcome(.destination(.dismiss)))) {
            $0.screen = .welcome(.init(destination: nil))
            $0.alert = AppFeature.networkRequestFailedAlert
        }
    }

    @MainActor
    func testUpsellDismissedWhenUpsellFlowCompleted() async {
        let state = AppFeature.State(
            screen: .welcome(.init(destination: .upsell(.loaded(planOptions: [], purchaseInProgress: true)))),
            networking: .authenticated(.auth(uid: "userid"))
        )

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.screen(.welcome(.upsold(tier: 2)))) {
            $0.$userTier.withLock { $0 = 2 }
            $0.screen = .main(.init())
        }
    }

    @MainActor
    func testSignOutClearsSharedStateAndTransitionsToWelcome() async {
        let mockVPNSession = VPNSessionMock(status: .disconnected)
        let state = AppFeature.State(
            screen: .welcome(.init(destination: .upsell(.loading))),
            networking: .authenticated(.auth(uid: "userid"))
        )
        state.$userTier.withLock { $0 = 0 }
        state.$userDisplayName.withLock { $0 = "username" }

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
            $0.logFileManager.dump = { _, _ in }
            $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
            $0.tunnelKeychain = TunnelKeychain(
                storeWireguardConfig: { _ in Data() },
                loadWireguardConfig: { Data() },
                clear: {}
            )
        }
        store.exhaustivity = .off

        await store.send(.signOut)
        await store.receive(\.networking.startLogout) {
            $0.isSigningOut = true
            $0.$userTier.withLock { $0 = nil }
            $0.$userDisplayName.withLock { $0 = nil }
            $0.screen = .welcome(.init())
        }
    }
}
