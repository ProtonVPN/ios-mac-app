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
        @MainActor
        func testIkeConfigurationEncodesLegacyFeatureSuffixesAndEndpointID() async throws {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: false, isEnabled: false)

            let features = VPNConnectionFeatures(
                netshield: .level2,
                vpnAccelerator: false,
                natType: .moderateNAT,
                portForwarding: true
            )
            let server = Server.mock
            let intent = ServerConnectionIntent.mock(server: server, protocolConfiguration: .ike, features: features)
            let expectedUsername = "username+pm+f2+nst+nr+pmp+ep:\(server.endpoint.id)"

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
