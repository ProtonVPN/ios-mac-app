//
//  Created on 7/25/24.
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

#if targetEnvironment(simulator)

import XCTest
import ComposableArchitecture
@testable import tvOS
@testable import CommonNetworking
@testable import Connection
@testable import LocalAgent
@testable import ExtensionManager
@testable import ConnectionFoundations
import Domain
import VPNSharedTesting

final class AppConnectionIntegrationTests: XCTestCase {

    @MainActor
    func testWaitsUntilTunnelDisconnectedBeforeSigningOut() async throws {
        let clock = TestClock()
        let mockVPNSession = VPNSessionMock(status: .connecting)
        let tunnelConfigurationCleared = XCTestExpectation(description: "Saved WG config should be removed from the keychain")
        let state = AppFeature.State(
            main: .init(
                currentTab: .settings,
                settings: .init(
                    userDisplayName: Shared<String?>(""),
                    userTier: Shared<Int?>(1),
                    mainBackground: .clear,
                    destination: nil,
                    alert: SettingsFeature.signOutAlert,
                    isLoading: false
                ),
                connection: .init(tunnelState: .connected(.init(logicalServer: .mock))),
                userLocation: Shared<UserLocation?>(UserLocation(ip: "", country: "", isp: ""))
            ),
            networking: .authenticated(.auth(uid: "sessionID"))
        )

        let alertService = AlertService.testValue
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
            $0.localAgent = LocalAgentMock(state: .disconnected)
            $0.networking = VPNNetworkingMock()
            $0.authKeychain = MockAuthKeychain()
            $0.vpnAuthenticationStorage = MockVpnAuthenticationStorage()
            $0.tunnelKeychain = TunnelKeychain(
                storeWireguardConfig: { _ in Data() },
                clear: { tunnelConfigurationCleared.fulfill() }
            )
        }

        store.exhaustivity = .off
        await store.send(\.main.connection.startObserving)
        await store.send(\.main.settings.alert.presented.signOut) {
            $0.shouldSignOutAfterDisconnecting = true
        }
        await store.receive(\.main.connection.disconnect)

        await clock.advance(by: .seconds(1)) // Wait until disconnect is finished
        await store.receive(\.main.connection.tunnel.tunnelStatusChanged.disconnected) {
            $0.shouldSignOutAfterDisconnecting = false
        }
        await store.receive(\.signOut)

        await fulfillment(of: [tunnelConfigurationCleared])
    }
}
#endif
