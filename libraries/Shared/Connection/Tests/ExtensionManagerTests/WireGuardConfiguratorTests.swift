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

#if DEBUG
    import CoreConnectionTestSupport
    import Dependencies
    import Domain
    import DomainTestSupport
    import Ergonomics
    @testable import ExtensionManager
    import Foundation
    import NetworkExtension
    import VPNShared
    import VPNSharedTesting
    import XCTest

    final class WireGuardConfiguratorTests: XCTestCase {
        /// The user's private key is required to complete tunnel configuration.
        /// Let's test that if keys aren't found in the keychain, they are generated.
        @MainActor
        func testGeneratesKeysIfMissing() async throws {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: true, isEnabled: false)

            let intent = ServerConnectionIntent.mock(protocolConfiguration: .wireGuard(.init(backend: .go, transport: .tls, features: .mock)))
            let bundleID = "big.bundle.id"

            let keysGenerated = XCTestExpectation(description: "Keys should have been generated")
            let configStored = XCTestExpectation(description: "WG Config should have been stored in the keychain")

            try await withDependencies {
                $0.date = .constant(.now)
                $0.bundleIDClient = .mock(bundleID: bundleID)
                $0.tunnelKeychain = .init(
                    storeWireguardConfig: { _ in
                        configStored.fulfill()
                        return Data()
                    },
                    loadWireguardConfig: { Data() },
                    clear: unimplemented("Tunnel keychain should not have been cleared")
                )
                $0.vpnAuthenticationStorage.getKeys = {
                    keysGenerated.fulfill()
                    return .mock()
                }
            } operation: {
                try await configurator.configure(&manager, for: .connection(intent))
            }

            XCTAssertEqual(manager.isEnabled, true)
            XCTAssertEqual(manager.isOnDemandEnabled, true)
            XCTAssertEqual(manager.vpnProtocolConfiguration?.wgProtocol, "tls")
            XCTAssertEqual(manager.providerBundleIdentifier, bundleID)

            #if os(macOS)
                // On macOS, configuration data is sent via XPC to the extension instead of being stored through
                // `tunnelKeychain.storeWireguardConfig`.
                await fulfillment(of: [keysGenerated], timeout: 1)
            #else
                await fulfillment(of: [keysGenerated, configStored], timeout: 1, enforceOrder: true)
            #endif
        }

        #if os(macOS)
            /// On macOS, if pushing the WireGuard config to the extension via XPC fails (no
            /// remote object, broken connection, etc.), the configurator must surface a typed
            /// error instead of silently returning a `NETunnelProviderProtocol` with no
            /// password reference (which would later fail to start with no actionable error).
            @MainActor
            func testMacOSXPCConfigWriteFailureSurfacesTypedError() async throws {
                let configurator = ManagerConfigurator.wireGuardConfigurator
                let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
                var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: false, isEnabled: false)
                let intent = ServerConnectionIntent.mock(protocolConfiguration: .wireGuard(.init(backend: .go, transport: .tls, ports: [0], features: .mock)))

                do {
                    try await withDependencies {
                        $0.date = .constant(.now)
                        $0.bundleIDClient = .mock(bundleID: "big.bundle.id")
                        $0.tunnelKeychain = .init(
                            storeWireguardConfig: { _ in Data() },
                            loadWireguardConfig: { Data() },
                            clear: {}
                        )
                        $0.vpnAuthenticationStorage.getKeys = { .mock() }
                        $0.wireguardExtensionConfigClient.pushConfig = { _ in false }
                    } operation: {
                        try await configurator.configure(&manager, for: .connection(intent))
                    }
                    XCTFail("Expected WireguardConfiguratorError.configurationXPCWriteFailed")
                } catch WireguardConfiguratorError.configurationXPCWriteFailed {
                    // Expected.
                } catch {
                    XCTFail("Expected configurationXPCWriteFailed, got \(error)")
                }
            }
        #endif

        @MainActor
        func testIkeConfigurationEncodesLegacyFeatureSuffixesAndEndpointID() async throws {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: false, isEnabled: false)

            let features = VPNConnectionFeatures(
                netshield: .level2,
                vpnAccelerator: false,
                bouncing: nil,
                natType: .moderateNAT,
                safeMode: false,
                portForwarding: true
            )
            let server = Server.mock
            let intent = ServerConnectionIntent.mock(server: server, protocolConfiguration: .ike, features: features)
            let labelSuffix = server.endpoint.label.map { "+b:\($0)" } ?? ""
            let expectedUsername = "username+pm+f2+nst\(labelSuffix)+nr+nsm+pmp+ep:\(server.endpoint.id)"

            try await withDependencies {
                $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .freeTier)
            } operation: {
                try await configurator.configure(&manager, for: .connection(intent))
            }

            let ikeConfig = try XCTUnwrap(manager.protocolConfiguration as? NEVPNProtocolIKEv2)
            XCTAssertEqual(ikeConfig.username, expectedUsername)
        }

        @MainActor
        func testIkeConfigurationThrowsWhenCredentialsCannotBeRead() async {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: false, isEnabled: false)
            let intent = ServerConnectionIntent.mock(protocolConfiguration: .ike)

            let failingKeychain = VpnKeychainMock(planName: "free", maxTier: .freeTier)
            failingKeychain.throwsOnFetch = true

            await XCTAssertThrowsErrorAsync {
                try await withDependencies {
                    $0.vpnKeychain = failingKeychain
                } operation: {
                    try await configurator.configure(&manager, for: .connection(intent))
                }
            } errorHandler: { error in
                guard case .ikeCredentialsUnavailable = error as? IkeConfiguratorError else {
                    XCTFail("Expected ikeCredentialsUnavailable error, got \(error)")
                    return
                }
            }
        }
    }

    private func XCTAssertThrowsErrorAsync(
        _ expression: @escaping () async throws -> Void,
        errorHandler: (Error) -> Void
    ) async {
        do {
            try await expression()
            XCTFail("Expected expression to throw")
        } catch {
            errorHandler(error)
        }
    }
#endif
