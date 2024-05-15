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
import XCTestDynamicOverlay
@testable import ProtonVPN_TV

final class SignInFeatureTests: XCTestCase {

    @MainActor
    func testSignInSuccess() async {
        let store = TestStore(initialState: SignInFeature.State.loadingSignInCode) {
            SignInFeature()
        }
        await store.send(\.authenticationFinished.success.authenticated, .mock)
        await store.receive(\.signInFinished.success)
    }

    @MainActor
    func testSignInFlowHappyPath() async {
        let clock = TestClock()
        let pollConf = ServerPollConfiguration.liveValue
        let mockSignInResponse = SignInCode(selector: "40-char-random-hex-string", userCode: "1234ABCD")

        let store = TestStore(initialState: SignInFeature.State.loadingSignInCode) {
            SignInFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.networkClient = .init(
                fetchSignInCode: { mockSignInResponse },
                forkedSession: { selector in
                    XCTAssertEqual(selector, mockSignInResponse.selector)
                    return .invalidSelector
                }
            )
        }

        await store.send(\.fetchSignInCode)
        await store.receive(\.codeFetchingFinished.success) {
            $0 = SignInFeature.State.waitingForAuthentication(
                code: mockSignInResponse,
                remainingAttempts: pollConf.failAfterAttempts
            )
        }

        store.dependencies.networkClient = .init(
            fetchSignInCode: { .init(selector: "", userCode: "")},
            forkedSession: { selector in
                XCTAssertEqual(selector, mockSignInResponse.selector)
                return .authenticated(.mock)
            }
        )

        await clock.advance(by: pollConf.delayBeforePollingStarts)
        await clock.advance(by: pollConf.period)

        await store.receive(\.pollServer) {
            $0 = SignInFeature.State.waitingForAuthentication(
                code: mockSignInResponse,
                remainingAttempts: pollConf.failAfterAttempts - 1
            )
        }
        await store.receive(\.authenticationFinished.success.authenticated)
        await store.receive(\.signInFinished.success)
    }

    @MainActor
    func testFetchSignInCodeFailure() async {
        let store = TestStore(initialState: SignInFeature.State.loadingSignInCode) {
            SignInFeature()
        } withDependencies: {
            $0[NetworkClient.self] = .init(
                fetchSignInCode: { throw "error" },
                forkedSession: { _ in throw "error" }
            )
        }

        await store.send(.fetchSignInCode)
        await store.receive(\.codeFetchingFinished.failure)
    }

    @MainActor
    func testSessionForkFailure() async {
        let mockCode = SignInCode(selector: "40-char-random-hex-string", userCode: "1234ABCD")

        let clock = TestClock()
        let store = TestStore(initialState: SignInFeature.State.loadingSignInCode) {
            SignInFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0[NetworkClient.self] = .init(
                fetchSignInCode: { mockCode },
                forkedSession: { _ in .invalidSelector }
            )
        }

        let pollConf = ServerPollConfiguration.liveValue

        await store.send(.fetchSignInCode)
        await store.receive(\.codeFetchingFinished.success) {
            $0 = SignInFeature.State.waitingForAuthentication(
                code: mockCode,
                remainingAttempts: pollConf.failAfterAttempts
            )
        }
        await clock.advance(by: pollConf.delayBeforePollingStarts)
        var failAfterAttempts = pollConf.failAfterAttempts

        for _ in 1...pollConf.failAfterAttempts {
            failAfterAttempts -= 1
            await clock.advance(by: pollConf.period)
            await store.receive(\.pollServer) {
                $0 = SignInFeature.State.waitingForAuthentication(
                    code: mockCode,
                    remainingAttempts: failAfterAttempts
                )
            }
            await store.receive(\.authenticationFinished.success.invalidSelector)
        }
        await clock.advance(by: pollConf.period)
        await store.receive(\.pollServer)
        await store.receive(\.signInFinished.failure)
    }
}
