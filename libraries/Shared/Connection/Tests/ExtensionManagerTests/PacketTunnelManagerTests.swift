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

    import CoreConnection
    import Dependencies
    import Domain
    import DomainTestSupport
    @testable import ExtensionManager
    import Foundation
    import IPCErgonomics
    @testable import LocalAgent
    import LocalAgentIPC
    import class NetworkExtension.NETunnelProviderProtocol
    import VPNCoreCommon
    import XCTest

    final class PacketTunnelManagerTests: XCTestCase {
        func testReturnsStatusOfActiveTunnel() async throws {
            let inactiveManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .ready)
            let activeManager = MockTunnelProviderManager(withBundleIdentifier: "abc", state: .ready)

            inactiveManager.session = VPNSessionMock(status: .disconnected)
            activeManager.session = VPNSessionMock(status: .connecting)

            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            inactiveManager.protocolConfiguration = config
            activeManager.protocolConfiguration = config

            try await withDependencies {
                $0.vpnManagerRepository.managers = { [.ike: inactiveManager, .wireGuard(.go): activeManager] }
            } operation: {
                let status = try await PacketTunnelManager().status
                XCTAssertEqual(status, .connecting(TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard(.go), peerIDs: [])))
            }
        }

        func testReturnsConnectedStatusWhenAnotherManagerIsDisconnecting() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let disconnectingManager = MockTunnelProviderManager(withBundleIdentifier: "disconnecting", state: .ready)
            let now = Date.now

            connectedManager.session = VPNSessionMock(status: .connected, connectedDate: now)
            disconnectingManager.session = VPNSessionMock(status: .disconnecting)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = {
                    [.ike: disconnectingManager, .wireGuard(.proTUN): connectedManager]
                }
                $0.extensionIPC.currentExtensionState = {
                    .connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil))
                }
            } operation: {
                let status = try await PacketTunnelManager().status
                XCTAssertEqual(
                    status,
                    .connected(
                        TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard(.proTUN), peerIDs: []),
                        DynamicConnectionData(currentPeerId: "peer-id", connectionDate: now, protocolConnectionData: .proTUN(.init(transport: .udp)))
                    )
                )
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

        func testStoppingTunnelStopsAllActiveManagers() async throws {
            let clock = TestClock()
            let ikeManager = MockTunnelProviderManager(withBundleIdentifier: "ike", state: .ready)
            ikeManager.session = VPNSessionMock(status: .connected)
            let wgManager = MockTunnelProviderManager(withBundleIdentifier: "wg", state: .ready)
            wgManager.session = VPNSessionMock(status: .connecting)

            let ikePrepared = XCTestExpectation(description: "Expected IKE manager to be prepared")
            let wgPrepared = XCTestExpectation(description: "Expected WireGuard manager to be prepared")

            try await withDependencies {
                $0.continuousClock = clock
                $0.vpnManagerRepository.managers = { [.ike: ikeManager, .wireGuard(.go): wgManager] }
                $0.vpnManagerRepository.prepareManager = { proto, _ in
                    switch proto {
                    case .ike:
                        ikePrepared.fulfill()
                        return ikeManager
                    case .wireGuard(.go):
                        wgPrepared.fulfill()
                        return wgManager
                    case .wireGuard(.proTUN):
                        XCTFail("Unexpected protocol")
                        return wgManager
                    }
                }
            } operation: {
                try await PacketTunnelManager().stopTunnel()
            }

            await fulfillment(of: [ikePrepared, wgPrepared], timeout: 1)
            XCTAssertEqual(ikeManager.session.status, .disconnecting)
            XCTAssertEqual(wgManager.session.status, .disconnecting)
        }
    }
#endif
