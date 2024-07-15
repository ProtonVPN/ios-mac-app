//
//  Created on 20/06/2024.
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
import Connection
import DomainTestSupport

final class ProtectionStatusFeatureTests: XCTestCase {

    @MainActor
    func testOnAppear() async {
        let store = TestStore(initialState: ProtectionStatusFeature.State()) {
            ProtectionStatusFeature()
        } withDependencies: {
            $0.userLocationService = .testValue
        }

        await store.send(.onAppear)
    }

    @MainActor
    func testUserTappedButtonConnect() async {
        let store = TestStore(initialState: ProtectionStatusFeature.State()) {
            ProtectionStatusFeature()
        }
        @Shared(.connectionState) var connectionState: ConnectionState? = .disconnected(nil)

        await store.send(.userTappedButton)
        await store.receive(\.delegate.userClickedConnect)
    }

    @MainActor
    func testUserTappedButtonCancel() async {
        let store = TestStore(initialState: ProtectionStatusFeature.State()) {
            ProtectionStatusFeature()
        }
        @Shared(.connectionState) var connectionState: ConnectionState?
        connectionState = .connecting(.ca)

        await store.send(.userTappedButton)
        await store.receive(\.delegate.userClickedCancel)
    }

    @MainActor
    func testUserTappedButtonDisconnect() async {
        let store = TestStore(initialState: ProtectionStatusFeature.State()) {
            ProtectionStatusFeature()
        }
        @Shared(.connectionState) var connectionState: ConnectionState? 
        connectionState = .connected(.mock, nil)

        await store.send(.userTappedButton)
        await store.receive(\.delegate.userClickedDisconnect)
    }

    @MainActor
    func testUserTappedButtonDisconnecting() async {
        let store = TestStore(initialState: ProtectionStatusFeature.State()) {
            ProtectionStatusFeature()
        }
        @Shared(.connectionState) var connectionState: ConnectionState? 
        connectionState = .disconnecting

        await store.send(.userTappedButton)
        await store.receive(\.delegate.userClickedConnect)
    }
}
