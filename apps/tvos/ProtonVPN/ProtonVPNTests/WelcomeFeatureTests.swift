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
import struct CommonNetworking.SessionAuthResponse
import class VPNShared.AuthCredentials
@testable import ProtonVPN_TV

final class WelcomeFeatureTests: XCTestCase {

    @MainActor
    func testShowCreateAccount() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        await store.send(.showCreateAccount) {
            $0.destination = .createAccount(.init())
        }
    }

    @MainActor
    func testSignInSuccess() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        await store.send(.showSignIn) {
            $0.destination = .signIn(.loadingSignInCode)
        }

        await store.send(.destination(.presented(.signIn(.signInFinished(.success(.mock)))))) {
            $0.destination = nil
        }
    }

    @MainActor
    func testDestinationDismiss() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        await store.send(.showSignIn) {
            $0.destination = .signIn(.loadingSignInCode)
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }
}

extension AuthCredentials {

    static let mock = AuthCredentials(
        username: "username",
        accessToken: "access_token",
        refreshToken: "refresh_token",
        sessionId: "session_id",
        userId: "user_id",
        scopes: ["scope"],
        mailboxPassword: nil
    )
}

extension SessionAuthResponse {
    static let mock = SessionAuthResponse(
        accessToken: "access_token",
        refreshToken: "refresh_token",
        uid: "session_id",
        userID: "user_id",
        scopes: ["scope"]
    )
}
