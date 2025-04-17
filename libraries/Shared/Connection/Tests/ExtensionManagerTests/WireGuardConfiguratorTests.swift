//
//  Created on 17/04/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import XCTest

import Ergonomics
import Domain
import DomainTestSupport
import VPNShared
import VPNSharedTesting
import CoreConnectionTestSupport

import Dependencies

@testable import ExtensionManager

final class WireGuardConfiguratorTests: XCTestCase {

    /// The user's private key is required to complete tunnel configuration.
    /// Let's test that if keys aren't found in the keychain, they are generated.
    @MainActor func testGeneratesKeysIfMissing() async throws {
        let configurator = ManagerConfigurator.wireGuardConfigurator
        let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
        var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: true, isEnabled: false)

        let intent = ServerConnectionIntent.mock(tunnelSettings: .init(transport: .tls, ports: [0], features: .mock))
        let bundleID = "big.bundle.id"

        let keysGenerated = XCTestExpectation(description: "Keys should have been generated")
        let configStored = XCTestExpectation(description: "WG Config should have been stored in the keychain")

        // Ideally we would hook into the `getKeys` function, but this is an old dependency/mock that isn't worth changing atm
        let vpnAuthStorage = MockVpnAuthenticationStorage()
        vpnAuthStorage.keysStored = { _ in keysGenerated.fulfill() }

        try await withDependencies {
            $0.date = .constant(.now)
            $0.bundleIDClient = .mock(bundleID: bundleID)
            $0.tunnelKeychain = .init(
                storeWireguardConfig: { config in
                    configStored.fulfill()
                    return Data()
                },
                clear: unimplemented("Tunnel keychain should not have been cleared")
            )
            $0.vpnAuthenticationStorage = vpnAuthStorage
        } operation: {
            try await configurator.configure(&manager, for: .connection(intent))
        }

        XCTAssertEqual(manager.isEnabled, true)
        XCTAssertEqual(manager.isOnDemandEnabled, true)
        XCTAssertEqual(manager.vpnProtocolConfiguration?.wgProtocol, "tls")
        XCTAssertEqual(manager.providerBundleIdentifier, bundleID)

        await fulfillment(of: [keysGenerated, configStored], timeout: 0, enforceOrder: true)
    }
}
