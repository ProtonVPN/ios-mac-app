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

final class WelcomeFeatureTests: XCTestCase {

    @MainActor
    func testShowCreateAccount() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        await store.send(.showCreateAccount) {
            $0.destination = .welcomeInfo(.createAccount)
        }
    }

    @MainActor
    func testSignInSuccess() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        await store.send(.showSignIn) {
            $0.destination = .signIn(.init(authentication: .loadingSignInCode))
        }

        await store.send(.destination(.presented(.signIn(.signInFinished(.success(.mock))))))
    }

    @MainActor
    func testDestinationDismiss() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        await store.send(.showSignIn) {
            $0.destination = .signIn(.init(authentication: .loadingSignInCode))
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    @MainActor
    func testCodeExpired() async {
        let store = TestStore(initialState: WelcomeFeature.State(destination: .signIn(.init(authentication: .waitingForAuthentication(code: .init(selector: "", userCode: ""), remainingAttempts: 0))))) {
            WelcomeFeature()
        } 
        await store.send(.destination(.presented(.signIn(.signInFinished(.failure(.authenticationAttemptsExhausted)))))) {
            $0.destination = .codeExpired(.init())
        }
    }

    @MainActor
    func testGenerateNewCode() async {
        let store = TestStore(initialState: WelcomeFeature.State(destination: .codeExpired(.init()))) {
            WelcomeFeature()
        }
        await store.send(.destination(.presented(.codeExpired(.generateNewCode)))) {
            $0.destination = .signIn(.init(authentication: .loadingSignInCode))
        }
    }

    @MainActor
    func testUserTierUpdatedToPaid() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        @Shared(.userTier) var userTier: Int?

        await store.send(.onAppear)

        userTier = 0

        await store.receive(\.userTierUpdated) {
            $0.destination = .welcomeInfo(.freeUpsellAlternative)
        }
    }

    @MainActor
    func testUserTierUpdatedToNil() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        @Shared(.userTier) var userTier: Int?

        await store.send(.onAppear)

        userTier = nil

        await store.receive(\.userTierUpdated)
        await store.receive(\.userTierUpdated) // for some reason setting nil sends the publisher event twice...

        userTier = 1 // to cancel the publisher
        await store.receive(\.userTierUpdated)
    }

    @MainActor
    func testUserTierUpdatedToFree() async {
        let store = TestStore(initialState: WelcomeFeature.State(destination: .signIn(.init(authentication: .loadingSignInCode)))) {
            WelcomeFeature()
        }
        @Shared(.userTier) var userTier: Int?

        await store.send(.onAppear)

        userTier = 1

        await store.receive(\.userTierUpdated) {
            $0.destination = nil
        }
    }
}
