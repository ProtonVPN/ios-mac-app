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

final class HomeFeatureTests: XCTestCase {
    @MainActor
    func testDisconnect() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.serverRepository = .previewValue
            $0.connectionClient = .testValue
            $0.continuousClock = clock
        }
        @Shared(.inMemory("connectionState")) var connectionState: ConnectFeature.ConnectionState?

        connectionState = .connected(countryCode: "OP", ip: "2.3.4.5")
        await store.send(.protectionStatus(.userClickedDisconnect))
        await store.receive(\.connect.userClickedDisconnect) { _ in
            connectionState = .disconnecting
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.connect.connectionTerminated) { _ in
            connectionState = .disconnected
        }
    }

    @MainActor
    func testConnect() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.serverRepository = .previewValue
            $0.connectionClient = .testValue
            $0.continuousClock = clock
        }
        @Shared(.inMemory("connectionState")) var connectionState: ConnectFeature.ConnectionState?

        connectionState = .disconnected
        await store.send(.protectionStatus(.userClickedConnect))
        await store.receive(\.connect.userClickedConnect) { _ in
            connectionState = .connecting(countryCode: nil)
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.connect.finishedConnecting.success) { _ in
            connectionState = .connected(countryCode: "AL", ip: "1.2.3.4")
        }
    }

    @MainActor
    func testCancelWhileConnectingTapped() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.serverRepository = .previewValue
        }
        @Shared(.inMemory("connectionState")) var connectionState: ConnectFeature.ConnectionState?

        connectionState = .connecting(countryCode: "PL")
        await store.send(.protectionStatus(.userClickedCancel))
        await store.receive(\.connect.userClickedCancel) { state in
            connectionState = .disconnected
        }
    }
}
