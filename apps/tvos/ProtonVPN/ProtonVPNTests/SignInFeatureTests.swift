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

final class SignInFeatureTests: XCTestCase {

    @MainActor
    func testSignInSuccess() async {
        let store = TestStore(initialState: SignInFeature.State()) {
            SignInFeature()
        }
        let credentials = AuthCredentials.emptyCredentials
        await store.send(.signInSuccess(credentials)) {
            $0.username = credentials.userID
        }
    }

    @MainActor
    func testSignInFlowHappyPath() async {
        let clock = TestClock()
        let store = TestStore(initialState: SignInFeature.State(serverPoll: .default)) {
            SignInFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0[NetworkClient.self] = .testValue
        }

        let pollConf = ServerPollConfiguration.default

        await store.send(.fetchSignInCode)
        await store.receive(\.presentSignInCode) {
            $0.signInCode = "1234ABCD"
            $0.selector = "40-char-random-hex-string"
        }
        await clock.advance(by: pollConf.delayBeforePollingStarts)
        await clock.advance(by: pollConf.period)
        await store.receive(\.pollServer) {
            $0.remainingAttempts = pollConf.failAfterAttempts - 1
            $0.username = "polled user"
        }
        await store.receive(\.signInSuccess)
    }

    @MainActor
    func testFetchSignInCodeFailure() async {
        let store = TestStore(initialState: SignInFeature.State(serverPoll: .default)) {
            SignInFeature()
        } withDependencies: {
            $0[NetworkClient.self] = .failureValue
        }

        await store.send(.fetchSignInCode)
    }

    @MainActor
    func testSessionForkFailure() async {
        let clock = TestClock()
        let store = TestStore(initialState: SignInFeature.State(serverPoll: .default)) {
            SignInFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0[NetworkClient.self] = .forkedSessionFailureValue
        }

        let pollConf = ServerPollConfiguration.default

        await store.send(.fetchSignInCode)
        await store.receive(\.presentSignInCode) {
            $0.signInCode = "1234ABCD"
            $0.selector = "40-char-random-hex-string"
        }
        await clock.advance(by: pollConf.delayBeforePollingStarts)
        var failAfterAttempts = pollConf.failAfterAttempts

        for _ in 1...pollConf.failAfterAttempts {
            failAfterAttempts -= 1
            await clock.advance(by: pollConf.period)
            await store.receive(\.pollServer) {
                $0.remainingAttempts = failAfterAttempts
            }
        }
        await clock.advance(by: pollConf.period)
        await store.receive(\.pollServer)
    }
}
