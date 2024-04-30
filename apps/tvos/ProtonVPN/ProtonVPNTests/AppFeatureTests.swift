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
@testable import ProtonVPN_TV

final class AppFeatureTests: XCTestCase {

    @MainActor
    func testLoggingOut() async {
        let state = AppFeature.State(main: MainFeature.State(currentTab: .home, settings: .init(userName: "user")))
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.main(.settings(.signOut))) {
            $0.main = nil
        }
    }

    @MainActor
    func testIgnoresActions() async {
        let state = AppFeature.State(main: MainFeature.State(currentTab: .home, settings: .init(userName: "user")))
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.main(.selectTab(.home)))
    }

    @MainActor
    func testShowCreateAccount() async {
        let state = AppFeature.State()
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.welcome(.showCreateAccount)) {
            $0.welcome.destination = .createAccount(.init())
        }
    }

    @MainActor
    func testSigningIn() async {
        let state = AppFeature.State(welcome: .init(destination: .signIn(.init())))
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        let credentials = AuthCredentials(userID: "userID", 
                                          uID: "",
                                          accessToken: "",
                                          refreshToken: "")
        await store.send(.welcome(.destination(.presented(.signIn(.signInSuccess(credentials)))))) { state in
            state.welcome.destination = nil
            state.main = .init(currentTab: .home, settings: .init(userName: "userID"))
        }
    }
}
