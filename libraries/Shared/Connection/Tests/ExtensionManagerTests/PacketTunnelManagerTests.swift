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

import Foundation
import class NetworkExtension.NETunnelProviderProtocol
import XCTest

import Dependencies

import Domain
import DomainTestSupport
@testable import ExtensionManager

final class PacketTunnelManagerTests: XCTestCase {

    func testCreatesAndLoadsManagerWithNoExistingManagers() async throws {
        let existingManagersLoaded = XCTestExpectation(description: "Tunnel Manager should check if a provider manager already exists")
        let newManagerLoaded = XCTestExpectation(description: "Tunnel Manager must load any newly created manager")

        let newManager = MockTunnelProviderManager.manager(state: .requiresLoad)

        newManager.loadFromPreferencesBlock = { newManagerLoaded.fulfill() }

        _ = try await withDependencies {
            $0.tunnelProviderManagerFactory = .init(
                create: { newManager },
                removeAll: unimplemented(),
                loadFromPreferences: {
                    existingManagersLoaded.fulfill()
                    return []
                }
            )
        } operation: { 
            try await PacketTunnelManager().status
        }

        await fulfillment(of: [existingManagersLoaded, newManagerLoaded], timeout: 1)
    }

    func testLoadsManagerWithMatchingBundleIdentifier() async throws {
        let existingManagersLoaded = XCTestExpectation(description: "Tunnel Manager should check if a provider manager already exists")

        let existingManager = MockTunnelProviderManager.manager(state: .ready)

        _ = try await withDependencies {
            $0.tunnelProviderManagerFactory = .init(
                create: unimplemented(),
                removeAll: unimplemented(),
                loadFromPreferences: {
                    existingManagersLoaded.fulfill()
                    return [existingManager]
                }
            )
        } operation: {
            try await PacketTunnelManager().status
        }

        await fulfillment(of: [existingManagersLoaded], timeout: 1)
    }

    /// In this test, we want to verify that the tunnel is configured however it might be necessary before it can be
    /// used to connect to the specified server.
    ///
    /// Configuration specifics are up to the `tunnelProviderConfigurator`.
    func testStartingTunnelToServerConfiguresExistingManager() async throws {
        let server = Server.mock
        let clock = TestClock()

        let providerManager = MockTunnelProviderManager.manager(state: .ready)

        let managerConfigured = XCTestExpectation(description: "Expected manager to be configured")
        let managerSaved = XCTestExpectation(description: "Manager must be saved after being configuration")
        let managerReloaded = XCTestExpectation(description: "Tunnel Manager must be reloaded after configuration")

        providerManager.saveToPreferencesBlock = { managerSaved.fulfill() }
        providerManager.loadFromPreferencesBlock = { managerReloaded.fulfill() }

        _ = try await withDependencies {
            $0.continuousClock = clock
            $0.tunnelProviderManagerFactory = .init(
                create: unimplemented(),
                removeAll: unimplemented(),
                loadFromPreferences: { [providerManager] }
            )
            $0.tunnelProviderConfigurator = .init(configure: { manager, operation in
                let mockManager = try XCTUnwrap(manager as? MockTunnelProviderManager)
                mockManager.isEnabled = true
                managerConfigured.fulfill()
            })
        } operation: {
            try await PacketTunnelManager().startTunnel(to: server)
        }

        await fulfillment(of: [managerConfigured, managerSaved, managerReloaded], timeout: 1, enforceOrder: true)
    }

    func testStoppingTunnelConfiguresCurrentManager() async throws {
        let clock = TestClock()

        let providerManager = MockTunnelProviderManager.manager(state: .ready)

        let managerConfigured = XCTestExpectation(description: "Expected manager to be configured")
        let managerSaved = XCTestExpectation(description: "Manager must be saved after being configuration")
        let managerReloaded = XCTestExpectation(description: "Tunnel Manager must be reloaded after configuration")

        providerManager.saveToPreferencesBlock = { managerSaved.fulfill() }
        providerManager.loadFromPreferencesBlock = { managerReloaded.fulfill() }

        _ = try await withDependencies {
            $0.continuousClock = clock
            $0.tunnelProviderManagerFactory = .init(
                create: unimplemented(),
                removeAll: unimplemented(),
                loadFromPreferences: { [providerManager] }
            )
            $0.tunnelProviderConfigurator = .init(configure: { manager, operation in
                let mockManager = try XCTUnwrap(manager as? MockTunnelProviderManager)
                mockManager.isOnDemandEnabled = false
                managerConfigured.fulfill()
            })
        } operation: {
            try await PacketTunnelManager().stopTunnel()
        }

        await fulfillment(of: [managerConfigured, managerSaved, managerReloaded], timeout: 1, enforceOrder: true)
    }
}

extension MockTunnelProviderManager {
    static func manager(
        withBundleIdentifier bundleIdentifier: String = "ch.protonmail.vpn.WireGuard-tvOS",
        state: MockTunnelProviderManager.MockProviderState = .ready
    ) -> MockTunnelProviderManager {
        let configuration = NETunnelProviderProtocol()
        configuration.providerBundleIdentifier = bundleIdentifier

        return MockTunnelProviderManager(
            session: VPNSessionMock(status: .disconnected),
            vpnProtocolConfiguration: configuration,
            isOnDemandEnabled: true,
            isEnabled: true,
            state: state
        )
    }
}
