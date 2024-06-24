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
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
        }
        await store.send(.onAppear)
        await store.receive(\.networking) { // startAcquiringSession
            $0.networking = .acquiringSession
        }
        await store.receive(\.networking) { // session fetched failure
            $0.networking = .unauthenticated(.network(internalError: ""))
        }
    }
}
