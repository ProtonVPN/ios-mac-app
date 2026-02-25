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

    @testable import CommonNetworking
    import ComposableArchitecture
    @testable import Connection
    import ConnectionTestSupport
    @testable import CoreConnection
    import Domain
    @testable import ExtensionManager
    @testable import LocalAgent
    import Network
    @testable import tvos_app
    import VPNShared
    import VPNSharedTesting
    import XCTest

    final class AppConnectionIntegrationTests: XCTestCase {
        @MainActor
        func testWaitsUntilTunnelDisconnectedBeforeSigningOut() async throws {
            let clock = TestClock()
            let mockVPNSession = VPNSessionMock(status: .connected)
            let tunnelConfigurationCleared = XCTestExpectation(description: "Saved WG config should be removed from the keychain")

            let state = AppFeature.State(
                screen: .main(.init(
                    currentTab: .settings,
                    settings: .init(
                        userDisplayName: Shared<String?>(value: ""),
                        userTier: Shared<Int?>(value: 1),
                        mainBackground: .init(value: .clear),
                        alert: SettingsFeature.signOutAlert,
                        isLoading: false
                    ),
                    connection: .connected,
                    userLocation: Shared<UserLocation?>(value: UserLocation(ip: "", country: "", isp: ""))
                )),
                networking: .authenticated(.auth(uid: "sessionID"))
            )
            let (nwPathStream, _) = AsyncStream.makeStream(of: Network.NWPath.self)

            let store = TestStore(initialState: state) {
                AppFeature()._printChanges()
            } withDependencies: {
                $0.continuousClock = clock
                $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
                $0.localAgent = LocalAgentMock(state: .connected)
                $0.networking = VPNNetworkingMock()
                $0.vpnAuthenticationStorage = VpnAuthenticationStorage.testStorage()
                $0.tunnelKeychain = TunnelKeychain(
                    storeWireguardConfig: { _ in Data() },
                    loadWireguardConfig: { Data() },
                    clear: { tunnelConfigurationCleared.fulfill() }
                )
                $0.connectionIntentStorage = .init(
                    getConnectionIntent: { .init(spec: .defaultFastest, server: .mock, tunnelSettings: .mock, features: .mock) },
                    set: { _ in }
                )
                $0.nwPathStream = { nwPathStream }
                $0.logFileManager.dump = { _, _ in }
            }
            store.exhaustivity = .off

            await store.send(\.screen.main.connection.input.onLaunch)
            await store.send(\.screen.main.settings.alert.presented.signOut)
            await store.receive(\.screen.main.signOut) {
                $0.shouldSignOutAfterDisconnecting = true
            }

            await store.receive(\.screen.main.connection.input.disconnect)

            await clock.advance(by: .seconds(1)) // Wait until disconnect is finished

            await fulfillment(of: [tunnelConfigurationCleared], timeout: .init(seconds: 10))
            await store.send(.networking(.stopObserving))
        }

        @MainActor
        func testSignsUserOutWhenSessionExpires() async throws {
            let clock = TestClock()
            let mockVPNSession = VPNSessionMock(status: .connected)
            let networkingDelegateMock = CoreNetworkingDelegateMock()
            let tunnelConfigurationCleared = XCTestExpectation(description: "Saved WG config should be removed from the keychain")

            let state = AppFeature.State(
                screen: .main(.init(
                    currentTab: .settings,
                    settings: .init(
                        userDisplayName: Shared<String?>(value: ""),
                        userTier: Shared<Int?>(value: 1),
                        mainBackground: .init(value: .clear),
                        isLoading: false
                    ),
                    connection: .connected,
                    userLocation: Shared<UserLocation?>(value: UserLocation(ip: "", country: "", isp: ""))
                )),
                networking: .authenticated(.auth(uid: "sessionID"))
            )
            state.$userTier.withLock { $0 = 1 } // Keep root screen in main while observing.
            let (nwPathStream, _) = AsyncStream.makeStream(of: Network.NWPath.self)

            let store = TestStore(initialState: state) {
                AppFeature()._printChanges()
            } withDependencies: {
                $0.continuousClock = clock
                $0.networkingDelegate = networkingDelegateMock
                $0.tunnelManager = MockTunnelManager(connection: mockVPNSession)
                $0.localAgent = LocalAgentMock(state: .connected)
                $0.networking = VPNNetworkingMock()
                $0.tunnelKeychain = TunnelKeychain(
                    storeWireguardConfig: { _ in Data() },
                    loadWireguardConfig: { Data() },
                    clear: { tunnelConfigurationCleared.fulfill() }
                )
                $0.connectionIntentStorage = .init(
                    getConnectionIntent: { .init(spec: .defaultFastest, server: .mock, tunnelSettings: .mock, features: .mock) },
                    set: { _ in }
                )
                $0.nwPathStream = { nwPathStream }
                $0.logFileManager.dump = { _, _ in }
            }
            store.exhaustivity = .off

            await store.send(\.networking.startObserving)

            // Push session expired event
            networkingDelegateMock.onLogout()
            await store.receive(\.networking.sessionExpired)
            await store.receive(\.networking.delegate.sessionExpired) {
                $0.alert = AppFeature.sessionExpiredAlert
            }
            await store.receive(\.requestSignOut)
            await store.receive(\.screen.main.signOut) {
                $0.shouldSignOutAfterDisconnecting = true
            }

            // Wait until disconnect is finished
            await clock.advance(by: .seconds(1))
            await fulfillment(of: [tunnelConfigurationCleared], timeout: .init(seconds: 10))
            await store.send(.networking(.stopObserving))
        }
    }
#endif
