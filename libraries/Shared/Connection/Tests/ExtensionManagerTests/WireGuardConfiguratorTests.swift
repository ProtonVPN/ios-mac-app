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
    import ConnectionShared
    @testable import CoreConnection
    import CoreConnectionTestSupport
    import Dependencies
    import Domain
    import DomainTestSupport
    import Ergonomics
    @testable import ExtensionManager
    import Foundation
    import NetworkExtension
    @testable import VPNAppCore
    import VPNCoreCommon
    import VPNShared
    import VPNSharedTesting
    import XCTest

    final class WireGuardConfiguratorTests: XCTestCase {
        #if os(macOS)
            @MainActor
            func testIkeConfigurationEncodesLegacyFeatureSuffixesAndEndpointID() async throws {
                let configurator = ManagerConfigurator.wireGuardConfigurator
                let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
                var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: false, isEnabled: false)

                let features = AgentTunnelFeatures(
                    netshield: .level2,
                    vpnAccelerator: false,
                    natType: .moderateNAT,
                    portForwarding: true
                )
                let server = Server.mock
                let intent = ServerConnectionIntent.mock(server: server, protocolConfiguration: .ike, features: features)
                let expectedUsername = "username+pm+f2+nst+nr+pmp+ep:\(server.endpoint.id)"

                try await withDependencies {
                    $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .free)
                } operation: {
                    try await configurator.configure(&manager, for: .connection(intent))
                }

                let ikeConfig = try XCTUnwrap(manager.protocolConfiguration as? NEVPNProtocolIKEv2)
                XCTAssertEqual(ikeConfig.username, expectedUsername)
            }
        #endif

        #if !os(tvOS)
            @MainActor
            func testDisconnectionClearsTheKillSwitchFlag() async throws {
                let configurator = ManagerConfigurator.wireGuardConfigurator
                let session = VPNSessionMock(status: .connected, connectedDate: nil)
                var manager: TunnelProviderManager = MockTunnelProviderManager(
                    session: session,
                    isOnDemandEnabled: true,
                    isEnabled: true
                )

                let connected = NETunnelProviderProtocol()
                connected.includeAllNetworks = true
                manager.protocolConfiguration = connected

                try await configurator.configure(&manager, for: .disconnection)

                let configuration = try XCTUnwrap(manager.protocolConfiguration)
                XCTAssertFalse(configuration.includeAllNetworks)
                XCTAssertFalse(manager.isOnDemandEnabled)
                XCTAssertTrue(manager.isEnabled)
            }
        #endif

        #if !os(tvOS)
            /// Advanced kill switch clears the exclusions Apple enables by default (push, carrier
            /// services, device communication). Standard keeps the platform defaults.
            @MainActor
            func testConnectionClosesDefaultBypassesOnlyForAdvanced() async throws {
                let configurator = ManagerConfigurator.wireGuardConfigurator
                let keychain = MockAuthKeychain()
                keychain.userId = "user-id"

                for (mode, expectExcluded) in [(KillSwitchMode.advanced, false), (.standard, true)] {
                    let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
                    var manager: TunnelProviderManager = MockTunnelProviderManager(
                        session: session,
                        isOnDemandEnabled: false,
                        isEnabled: false
                    )
                    let intent = ServerConnectionIntent.mock(
                        server: .mock,
                        protocolConfiguration: .wireGuard(.init(backend: .proTUN, transport: .udp)),
                        tunnelFeatures: .init(killSwitchMode: mode, excludeLocalNetworks: false)
                    )

                    try await withDependencies {
                        $0.authKeychain = keychain
                        $0.credentiallessHelper = .init(isCredentialLess: { false })
                        $0.connectionFeatureProvider = .init(
                            connectionFeatures: { .mock },
                            requestedFeatures: { .init(killSwitchMode: mode, excludeLocalNetworks: false) },
                            connectionProtocol: { .smartProtocol }
                        )
                    } operation: {
                        try await configurator.configure(&manager, for: .connection(intent))
                    }

                    let config = try XCTUnwrap(manager.protocolConfiguration as? NETunnelProviderProtocol)
                    XCTAssertTrue(config.includeAllNetworks)
                    XCTAssertEqual(config.excludeCellularServices, expectExcluded)
                    XCTAssertEqual(config.excludeAPNs, expectExcluded)
                    if #available(iOS 17.4, macOS 14.4, *) {
                        XCTAssertEqual(config.excludeDeviceCommunication, expectExcluded)
                    }
                }
            }

            /// The zero-peer tunnel takes `excludeLocalNetworks` from the user's preference instead of
            /// the platform default, which allows LAN on iOS but not on macOS. It clears the default
            /// exclusions unconditionally, because it only exists under Advanced.
            @MainActor
            func testZeroPeerColdStartFollowsLANPreferenceAndClosesDefaultBypasses() async throws {
                let configurator = ManagerConfigurator.wireGuardConfigurator
                let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
                var manager: TunnelProviderManager = MockTunnelProviderManager(
                    session: session,
                    isOnDemandEnabled: true,
                    isEnabled: false
                )
                let keychain = MockAuthKeychain()
                keychain.userId = "user-id"

                try await withDependencies {
                    $0.authKeychain = keychain
                    $0.uuid = .incrementing
                    $0.connectionFeatureProvider = .init(
                        connectionFeatures: { .mock },
                        requestedFeatures: { .init(killSwitchMode: .advanced, excludeLocalNetworks: true) },
                        connectionProtocol: { .smartProtocol }
                    )
                } operation: {
                    try await configurator.configure(&manager, for: .zeroPeerColdStart)
                }

                let config = try XCTUnwrap(manager.protocolConfiguration as? NETunnelProviderProtocol)
                XCTAssertTrue(config.includeAllNetworks)
                XCTAssertTrue(config.excludeLocalNetworks)
                XCTAssertFalse(config.excludeCellularServices)
                XCTAssertFalse(config.excludeAPNs)
                XCTAssertNotNil(config.requestId)
                XCTAssertFalse(manager.isOnDemandEnabled)
                XCTAssertTrue(manager.isEnabled)

                let protunConfig = try ProTUNConfigurationCoder.decode(from: config)
                XCTAssertTrue(protunConfig.peers.isEmpty)
            }

            /// Switching a live tunnel into zero-peer blocking in place drops the peers, clears the
            /// default exclusions, and records the requested `excludeLocalNetworks` value, so the
            /// in-place zero-peer tunnel matches a freshly started one.
            @MainActor
            func testZeroPeerUpdateClosesDefaultBypassesAndStatesLANPosture() throws {
                let protocolConfiguration = NETunnelProviderProtocol()
                let peers = try Server.mock.peerInfo(using: WireguardConfig())
                try ProTUNConfigurationCoder.encode(
                    configuration: .init(preferredTransport: .udp, peers: peers, dnsServers: []),
                    to: protocolConfiguration
                )
                XCTAssertTrue(protocolConfiguration.excludeCellularServices)

                try protocolConfiguration.apply(update: .zeroPeer(using: ConnectionSpec(), allowLAN: false))

                XCTAssertTrue(protocolConfiguration.includeAllNetworks)
                XCTAssertFalse(protocolConfiguration.excludeLocalNetworks)
                XCTAssertFalse(protocolConfiguration.excludeCellularServices)
                XCTAssertFalse(protocolConfiguration.excludeAPNs)

                let updated = try ProTUNConfigurationCoder.decode(from: protocolConfiguration)
                XCTAssertTrue(updated.peers.isEmpty)
            }
        #endif

        @MainActor
        func testProTUNConfigurationOmitsAgentSettingsForCredentiallessAccounts() throws {
            let protocolConfiguration = NETunnelProviderProtocol()
            let keychain = MockAuthKeychain()
            keychain.userId = "user-id"

            try withDependencies {
                $0.authKeychain = keychain
                $0.credentiallessHelper = .init(isCredentialLess: { true })
                var featureProvider = ConnectionFeatureProvider.testValue
                featureProvider.connectionFeatures = { AgentTunnelFeatures(netshield: .level2, vpnAccelerator: true, natType: .strictNAT, portForwarding: true) }
                $0.connectionFeatureProvider = .testValue
            } operation: {
                try ManagerConfigurator.encodeProTUNConfiguration(
                    connectionIntent: .mock(server: .mock),
                    on: protocolConfiguration
                )
            }

            let config = try ProTUNConfigurationCoder.decode(from: protocolConfiguration)
            XCTAssertNil(config.netShieldLevel)
            XCTAssertNil(config.vpnAccelerator)
            XCTAssertNil(config.portForwarding)
            XCTAssertNil(config.randomNat)
        }

        /// Declaring the certificate out of date should only update the invalidation timestamp, without affecting any
        /// other tunnel configuration values.
        @MainActor
        func testCertificateInvalidationRecordsTheCurrentDate() async throws {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(
                session: session,
                isOnDemandEnabled: false,
                isEnabled: false
            )
            manager.protocolConfiguration = NETunnelProviderProtocol()
            let now = Date(timeIntervalSince1970: 1_800_000_000)

            try await withDependencies {
                $0.date.now = now
            } operation: {
                try await configurator.configure(&manager, for: .certificateInvalidation)
            }

            XCTAssertEqual(manager.vpnProtocolConfiguration?.certificateInvalidationDate, now)
            XCTAssertFalse(manager.isOnDemandEnabled)
            XCTAssertFalse(manager.isEnabled)
        }

        /// A manager with no configuration has never started a tunnel. The configurator throws so that the repository
        /// does not save a new configuration for it.
        @MainActor
        func testCertificateInvalidationThrowsWithoutAConfiguration() async {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(
                session: session,
                isOnDemandEnabled: false,
                isEnabled: false
            )

            await XCTAssertThrowsErrorAsync {
                try await configurator.configure(&manager, for: .certificateInvalidation)
            } errorHandler: { error in
                guard case .incorrectProtocolConfiguration = error as? WireguardConfiguratorError else {
                    XCTFail("Expected incorrectProtocolConfiguration error, got \(error)")
                    return
                }
            }

            XCTAssertNil(manager.vpnProtocolConfiguration)
        }

        /// Connecting builds a new provider configuration. The invalidation recorded on the old one has to carry over,
        /// because the tunnel that connection starts is the one that discards the certificate.
        @MainActor
        func testConnectingKeepsTheRecordedCertificateInvalidation() async throws {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            let invalidationDate = Date(timeIntervalSince1970: 1_800_000_000)
            let previousConfiguration = NETunnelProviderProtocol()
            previousConfiguration.certificateInvalidationDate = invalidationDate
            var manager: TunnelProviderManager = MockTunnelProviderManager(
                session: session,
                isOnDemandEnabled: false,
                isEnabled: false
            )
            manager.protocolConfiguration = previousConfiguration
            let keychain = MockAuthKeychain()
            keychain.userId = "user-id"
            let intent = ServerConnectionIntent.mock(
                server: .mock,
                protocolConfiguration: .wireGuard(.init(backend: .proTUN, transport: .udp))
            )

            try await withDependencies {
                $0.authKeychain = keychain
                $0.credentiallessHelper = .init(isCredentialLess: { false })
                $0.connectionFeatureProvider = .init(
                    connectionFeatures: { .mock },
                    requestedFeatures: { .mock },
                    connectionProtocol: { .smartProtocol }
                )
            } operation: {
                try await configurator.configure(&manager, for: .connection(intent))
            }

            XCTAssertEqual(manager.vpnProtocolConfiguration?.certificateInvalidationDate, invalidationDate)
        }

        @MainActor
        func testIkeConfigurationThrowsWhenCredentialsCannotBeRead() async {
            let configurator = ManagerConfigurator.wireGuardConfigurator
            let session = VPNSessionMock(status: .disconnected, connectedDate: nil)
            var manager: TunnelProviderManager = MockTunnelProviderManager(session: session, isOnDemandEnabled: false, isEnabled: false)
            let intent = ServerConnectionIntent.mock(protocolConfiguration: .ike)

            let failingKeychain = VpnKeychainMock(planName: "free", maxTier: .free)
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
