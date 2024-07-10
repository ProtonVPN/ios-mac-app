//
//  Created on 21/06/2024.
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
@testable import tvOS
@testable import CommonNetworking
@testable import VPNShared
@testable import VPNSharedTesting
import ProtonCoreNetworking

final class SessionNetworkingFeatureTests: XCTestCase {

    @MainActor
    func testEmptyCases() async {
        let store = TestStore(initialState: SessionNetworkingFeature.State.unauthenticated(nil)) {
            SessionNetworkingFeature()
        }
        await store.send(.delegate(.displayName(nil)))
        await store.send(.delegate(.tier(0)))
        await store.send(.forkedSessionAuthenticated(.failure("")))
    }

    @MainActor
    func testSessionFetchedFailure() async {
        let store = TestStore(initialState: SessionNetworkingFeature.State.unauthenticated(nil)) {
            SessionNetworkingFeature()
        }
        await store.send(.sessionFetched(.failure(""))) {
            $0 = .unauthenticated(.network(internalError: ""))
        }
    }

    @MainActor
    func testSessionFetchedSessionUnavailableAndNotFetched() async {
        let store = TestStore(initialState: SessionNetworkingFeature.State.unauthenticated(nil)) {
            SessionNetworkingFeature()
        }
        await store.send(.sessionFetched(.success(.sessionUnavailableAndNotFetched))) {
            $0 = .unauthenticated(.sessionUnavailable)
        }
    }

    @MainActor
    func testSessionExpired() async {
        let store = TestStore(initialState: SessionNetworkingFeature.State.authenticated(.unauth(uid: ""))) {
            SessionNetworkingFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
        }
        await store.send(.sessionExpired) {
            $0 = .unauthenticated(nil)
        }
        await store.receive(\.startLogout)
        await store.receive(\.startAcquiringSession) {
            $0 = .acquiringSession
        }
        await store.receive(\.sessionFetched.failure) {
            $0 = .unauthenticated(.network(internalError: ""))
        }
    }

    @MainActor
    func testStartLogout() async {
        let authKeychainCleared = expectation(description: "Should call clear keychain")
        let keychainMock = MockAuthKeychain()
        keychainMock.credentialsWereCleared = { authKeychainCleared.fulfill() }

        let store = TestStore(initialState: SessionNetworkingFeature.State.authenticated(.auth(uid: ""))) {
            SessionNetworkingFeature()
        } withDependencies: {
            $0.authKeychain = keychainMock
            $0.networking = VPNNetworkingMock()
        }
        await store.send(.startLogout)
        await fulfillment(of: [authKeychainCleared], timeout: 1)
        await store.receive(\.startAcquiringSession) {
            $0 = .acquiringSession
        }
        await store.receive(\.sessionFetched.failure) {
            $0 = .unauthenticated(.network(internalError: ""))
        }
    }

    @MainActor
    func testForkedSessionAuthenticatedButUserTierFailed() async {
        let e = expectation(description: "Should store credentials")
        let keychainMock = MockAuthKeychain()
        keychainMock.credentialsWereStored = { e.fulfill() }
        let store = TestStore(initialState: SessionNetworkingFeature.State.unauthenticated(nil)) {
            SessionNetworkingFeature()
        } withDependencies: {
            $0.authKeychain = keychainMock
            $0.networking = VPNNetworkingMock()
            $0.vpnAuthenticationStorage = MockVpnAuthenticationStorage()
        }
        store.exhaustivity = .off
        await store.send(.forkedSessionAuthenticated(.success(.mock)))
        await store.receive(\.startLogout)
        await fulfillment(of: [e])
    }

    @MainActor
    func testUserTier0Retrieved() async {
        let e = expectation(description: "Should call clear keychain")
        let keychainMock = MockAuthKeychain()
        keychainMock.credentialsWereCleared = { e.fulfill() }
        let store = TestStore(initialState: SessionNetworkingFeature.State.authenticated(.auth(uid: ""))) {
            SessionNetworkingFeature()
        } withDependencies: {
            $0.authKeychain = keychainMock
            $0.networking = VPNNetworkingMock()
            $0.vpnAuthenticationStorage = MockVpnAuthenticationStorage()
        }
        store.exhaustivity = .off
        await store.send(.userTierRetrieved(0, .auth(uid: "")))
        await store.receive(\.startLogout)
        await fulfillment(of: [e])
    }

    @MainActor
    func testUserTier1Retrieved() async {
        let store = TestStore(initialState: SessionNetworkingFeature.State.authenticated(.unauth(uid: ""))) {
            SessionNetworkingFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
        }
        await store.send(.userTierRetrieved(1, .auth(uid: ""))) {
            $0 = .authenticated(.auth(uid: ""))
        }
        await store.receive(\.delegate)
    }

    @MainActor
    func testSessionFetchedSessionWithAuthCredentials() async {
        let store = TestStore(initialState: SessionNetworkingFeature.State.unauthenticated(nil)) {
            SessionNetworkingFeature()
        } withDependencies: {
            $0.networking = VPNNetworkingMock()
        }
        let cred = AuthCredential(Credential(.mock))
        await store.send(.sessionFetched(.success(.sessionAlreadyPresent(cred)))) {
            $0 = .authenticated(.auth(uid: "session_id"))
        }
    }
}
