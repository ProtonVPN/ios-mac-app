//
//  Created on 06/06/2024.
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

#if targetEnvironment(simulator) // `MockTunnelManager` is only built for the simulator
import Foundation
import XCTest

import ComposableArchitecture

import Domain
import DomainTestSupport
@testable import ExtensionManager

final class ExtensionManagerFeatureTests: XCTestCase {

    @MainActor
    func testRequestsTunnelStart() async {
        let mockManager = MockTunnelManager()
        let mockClock = TestClock()

        mockManager.connection = MockVPNConnection(
            status: .disconnected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let state = ExtensionFeature.State.disconnected
        let store = TestStore(initialState: state) {
            ExtensionFeature()
        } withDependencies: {
            $0.continuousClock = mockClock
            $0.tunnelManager = mockManager
            $0.date = .constant(.now)
        }

        await store.send(.startObservingStateChanges)
        await store.receive(\.tunnelStatusChanged)

        let server = VPNServer.mock
        let features = VPNConnectionFeatures.mock

        await store.send(.connect(server, features)) {
            $0 = .connecting(server, features)
        }

        await store.receive(\.tunnelStarted.success)
        // NEVPNStatus is not @CasePathable.
        // We could improve testability here by mirroring it creating our own VPNStatus to mirror it
        await store.receive(\.tunnelStatusChanged) // .connecting

        await mockClock.advance(by: .seconds(1))
        await store.receive(\.tunnelStatusChanged) { // .connected
            $0 = .connected
        }

        await store.send(.stopObservingStateChanges)
    }

    @MainActor
    func testStateSetToConnectedIfExistingTunnelIsConencted() async {
        let mockManager = MockTunnelManager()
        mockManager.connection = MockVPNConnection(
            status: .connected,
            connectedDate: nil,
            lastDisconnectError: nil
        )

        let state = ExtensionFeature.State.disconnected
        let store = TestStore(initialState: state) {
            ExtensionFeature()
        } withDependencies: {
            $0.tunnelManager = mockManager
        }

        await store.send(.startObservingStateChanges)

        await store.receive(\.tunnelStatusChanged) {
            $0 = .connected
        }

        await store.send(.stopObservingStateChanges)
    }

}
#endif
