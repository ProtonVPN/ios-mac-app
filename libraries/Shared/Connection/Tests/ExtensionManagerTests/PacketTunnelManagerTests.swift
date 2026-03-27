//
//  Created on 07/06/2024.
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

#if DEBUG

    import Foundation
    import class NetworkExtension.NETunnelProviderProtocol
    import XCTest

    import Dependencies

    import Domain
    import DomainTestSupport
    @testable import ExtensionManager

    final class PacketTunnelManagerTests: XCTestCase {
        func testReturnsStatusOfActiveTunnel() async throws {
            let inactiveManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .ready)
            let activeManager = MockTunnelProviderManager(withBundleIdentifier: "abc", state: .ready)

            inactiveManager.session = VPNSessionMock(status: .disconnected)
            activeManager.session = VPNSessionMock(status: .connecting)

            try await withDependencies {
                // $0.continuousClock = clock
                $0.vpnManagerRepository.managers = { [.ike: inactiveManager, .wireGuard(.go): activeManager] }
            } operation: {
                let status = try await PacketTunnelManager().status
                XCTAssertEqual(status, .connecting)
            }
        }

        /// In this test, we want to verify that the tunnel is configured however it might be necessary before it can be
        /// used to connect to the specified server.
        ///
        /// Configuration specifics are up to the `tunnelProviderConfigurator`.
        func testStartingTunnelToServerConfiguresExistingManager() async throws {
            let tunnelSettings = TunnelSettings.mock
            let intent = ServerConnectionIntent(spec: .defaultFastest, server: .mock, protocolConfiguration: .wireGuard(tunnelSettings), features: .mock)
            let clock = TestClock()

            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .ready)

            let managerConfigured = XCTestExpectation(description: "Expected manager to be configured")

            try await withDependencies {
                $0.continuousClock = clock
                $0.vpnManagerRepository.prepareManager = { _, _ in
                    managerConfigured.fulfill()
                    return providerManager
                }
            } operation: {
                try await PacketTunnelManager().startTunnel(with: intent)
            }

            await fulfillment(of: [managerConfigured], timeout: 1)
        }

        func testStoppingTunnelConfiguresCurrentManager() async throws {
            let clock = TestClock()

            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .ready)
            providerManager.session = VPNSessionMock(status: .connected)

            let managerConfigured = XCTestExpectation(description: "Expected manager to be configured")

            try await withDependencies {
                $0.continuousClock = clock
                $0.vpnManagerRepository.managers = { [.wireGuard(.go): providerManager] }
                $0.vpnManagerRepository.prepareManager = { _, _ in
                    managerConfigured.fulfill()
                    return providerManager
                }
            } operation: {
                try await PacketTunnelManager().stopTunnel()
            }

            await fulfillment(of: [managerConfigured], timeout: 1)
        }
    }
#endif
