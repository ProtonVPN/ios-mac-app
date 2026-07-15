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
    import ExtensionIPC
    @testable import ExtensionManager
    import Foundation
    import IPCErgonomics
    @testable import LocalAgent
    import LocalAgentIPC
    import class NetworkExtension.NETunnelProviderProtocol
    import os
    import Testing
    import VPNCoreCommon

    @Suite(.serialized)
    struct PacketTunnelManagerTests {
        @Test
        func returnsStatusOfActiveTunnel() async throws {
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

            let status = try await withDependencies {
                $0.vpnManagerRepository.managers = { [.ike: inactiveManager, .wireGuard: activeManager] }
                $0.extensionIPC.currentExtensionState = { (.connecting(peerID: nil, waitReason: .unset), nil) }
            } operation: {
                try await PacketTunnelManager().status
            }

            #expect(status == .connecting(TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: [])))
        }

        @Test
        func returnsConnectedStatusWhenAnotherManagerIsDisconnecting() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let disconnectingManager = MockTunnelProviderManager(withBundleIdentifier: "disconnecting", state: .ready)
            let now = Date.now

            connectedManager.session = VPNSessionMock(status: .connected, connectedDate: now)
            disconnectingManager.session = VPNSessionMock(status: .disconnecting)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full
            let requestId = UUID()
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            // `.connected` is gated on the applied request ID matching the config's, so they must agree.
            config.setProviderConfiguration(value: requestId.uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = {
                    [.ike: disconnectingManager, .wireGuard: connectedManager]
                }
                $0.extensionIPC.currentExtensionState = {
                    (.connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)), requestId)
                }
            } operation: {
                try await PacketTunnelManager().status
            }

            #expect(
                status == .connected(
                    TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"]),
                    DynamicConnectionData(currentPeerId: "peer-id", connectionDate: now, protocolConnectionData: .proTUN(.init(transport: .udp)))
                )
            )
        }

        /// A briefly-`.connecting` `NEVPNStatus` (the in-place-save blip) shouldn't override an already-quiesced
        /// `.connected` extension state.
        @Test
        func returnsConnectedStatusWhenSessionBrieflyReportsConnectingDuringConfigUpdate() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let now = Date.now

            connectedManager.session = VPNSessionMock(status: .connecting, connectedDate: now)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full
            let requestId = UUID()
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            config.setProviderConfiguration(value: requestId.uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                $0.extensionIPC.currentExtensionState = {
                    (.connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)), requestId)
                }
            } operation: {
                try await PacketTunnelManager().status
            }

            #expect(
                status == .connected(
                    TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"]),
                    DynamicConnectionData(currentPeerId: "peer-id", connectionDate: now, protocolConnectionData: .proTUN(.init(transport: .udp)))
                )
            )
        }

        /// Covers the `inPlaceUpdate` path rather than `quiesced`: the persisted id hasn't caught up to the requested
        /// one yet, but a feature-only update can't move the tunnel off its peer, so `.connected` still wins.
        @Test
        func returnsConnectedForInPlaceFeatureUpdateBeforePersistedIdCatchesUp() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let now = Date.now

            // The `.connecting` status is the brief blip from saving NE preferences in place.
            connectedManager.session = VPNSessionMock(status: .connecting, connectedDate: now)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full

            // Both the persisted config and the extension still report the previous request id.
            let previousId = UUID()
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            config.setProviderConfiguration(value: previousId.uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            // A feature-only update (no peer change), so the shortcut applies even though the ids don't match yet.
            let update = ConnectionUpdate(customDNS: true)

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                $0.extensionIPC.currentExtensionState = {
                    (.connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)), previousId)
                }
            } operation: {
                let manager = PacketTunnelManager()
                _ = try await manager.sendProTUN(request: .init(payload: .updateConfiguration(update)))
                return try await manager.status
            }

            #expect(
                status == .connected(
                    TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"]),
                    DynamicConnectionData(currentPeerId: "peer-id", connectionDate: now, protocolConnectionData: .proTUN(.init(transport: .udp)))
                )
            )
        }

        /// The opposite case: a peer-affecting update disables the shortcut, so `.connecting` is reported as-is until
        /// the extension confirms it applied the update.
        @Test
        func returnsConnectingForPeerAffectingUpdateUntilExtensionConfirms() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let now = Date.now

            connectedManager.session = VPNSessionMock(status: .connecting, connectedDate: now)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full

            let previousId = UUID()
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            config.setProviderConfiguration(value: previousId.uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            // A peer-affecting update (new location): the shortcut must not apply.
            let update = ConnectionUpdate(location: .init(spec: .defaultFastest, peers: []))

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                $0.extensionIPC.currentExtensionState = {
                    (.connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)), previousId)
                }
            } operation: {
                let manager = PacketTunnelManager()
                _ = try await manager.sendProTUN(request: .init(payload: .updateConfiguration(update)))
                return try await manager.status
            }

            #expect(status == .connecting(TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"])))
        }

        /// The in-flight marker must be cleared once the extension catches up, or it would keep hiding a later real
        /// reconnect for the rest of the session.
        @Test
        func clearsInFlightUpdateOnceExtensionQuiesces() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let now = Date.now

            connectedManager.session = VPNSessionMock(status: .connected, connectedDate: now)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full

            // The persisted config has caught up to the requested id — the state the extension settles on.
            let update = ConnectionUpdate(customDNS: true)
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            config.setProviderConfiguration(value: update.id.uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            let inFlightAfterQuiesce = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                // The extension reports it applied exactly the update we requested.
                $0.extensionIPC.currentExtensionState = {
                    (.connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)), update.id)
                }
            } operation: {
                let manager = PacketTunnelManager()
                _ = try await manager.sendProTUN(request: .init(payload: .updateConfiguration(update)))
                _ = try await manager.status // reading status once caught up clears the marker
                return manager.inFlightConfigurationUpdate.withLock { $0 }
            }

            #expect(inFlightAfterQuiesce == nil)
        }

        @Test
        func rollsBackInFlightUpdateWhenSendingFails() async {
            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "connected")
            (providerManager.session as? VPNSessionMock)?.messageHandler = { _, _ throws(ProviderMessageError) in
                throw .notSupported
            }
            let manager = PacketTunnelManager()

            do {
                _ = try await withDependencies {
                    $0.vpnManagerRepository.managers = { [.wireGuard: providerManager] }
                } operation: {
                    try await manager.sendProTUN(request: .init(payload: .updateConfiguration(.init(customDNS: true))))
                }
                #expect(Bool(false), "Expected provider message send to fail")
            } catch {}

            #expect(manager.inFlightConfigurationUpdate.withLock { $0 } == nil)
        }

        #if !os(tvOS)
            @Test
            func managedConfigurationUpdatesCachedWireGuardManager() async throws {
                let manager = MockTunnelProviderManager(withBundleIdentifier: "wireguard")
                let requestId = UUID()
                let counts = OSAllocatedUnfairLock(initialState: (saves: 0, loads: 0))
                manager.saveToPreferencesBlock = { counts.withLock { $0.saves += 1 } }
                manager.loadFromPreferencesBlock = { counts.withLock { $0.loads += 1 } }

                try await withDependencies {
                    $0.vpnManagerRepository.managers = { [.wireGuard: manager] }
                } operation: {
                    try await ManagedConfigurationMirror.apply(.init(
                        includeAllNetworks: true,
                        excludeLocalNetworks: true,
                        isOnDemandEnabled: false,
                        requestId: requestId
                    ))
                }

                #expect(manager.vpnProtocolConfiguration?.includeAllNetworks == true)
                #expect(manager.vpnProtocolConfiguration?.excludeLocalNetworks == true)
                #expect(manager.vpnProtocolConfiguration?.requestId == requestId)
                #expect(manager.isOnDemandEnabled == false)
                #expect(counts.withLock { $0.saves } == 1)
                #expect(counts.withLock { $0.loads } == 1)
            }
        #endif

        @Test
        func managedConfigurationFailsWithoutWireGuardManager() async {
            do {
                try await withDependencies {
                    $0.vpnManagerRepository.managers = { [:] }
                } operation: {
                    try await ManagedConfigurationMirror.apply(.init(
                        includeAllNetworks: true,
                        excludeLocalNetworks: false,
                        isOnDemandEnabled: nil,
                        requestId: UUID()
                    ))
                }
                #expect(Bool(false), "Expected missing manager to fail")
            } catch {}
        }

        /// In this test, we want to verify that the tunnel is configured however it might be necessary before it can be
        /// used to connect to the specified server.
        ///
        /// Configuration specifics are up to the `tunnelProviderConfigurator`.
        @Test
        func startingTunnelToServerConfiguresExistingManager() async throws {
            let tunnelSettings = TunnelSettings.mock
            let intent = ServerConnectionIntent(spec: .defaultFastest, server: .mock, protocolConfiguration: .wireGuard(tunnelSettings), features: .mock)
            let clock = TestClock()

            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .ready)

            try await confirmation("Expected manager to be configured") { managerConfigured in
                try await withDependencies {
                    $0.continuousClock = clock
                    $0.vpnManagerRepository.prepareManager = { _, _ in
                        managerConfigured()
                        return providerManager
                    }
                } operation: {
                    try await PacketTunnelManager().startTunnel(with: intent)
                }
            }
        }

        @Test
        func stoppingTunnelConfiguresCurrentManager() async throws {
            let clock = TestClock()

            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "123", state: .ready)
            providerManager.session = VPNSessionMock(status: .connected)

            try await confirmation("Expected manager to be configured") { managerConfigured in
                try await withDependencies {
                    $0.continuousClock = clock
                    $0.vpnManagerRepository.managers = { [.wireGuard: providerManager] }
                    $0.vpnManagerRepository.prepareManager = { _, _ in
                        managerConfigured()
                        return providerManager
                    }
                } operation: {
                    try await PacketTunnelManager().stopTunnel()
                }
            }
        }

        @Test
        func stoppingTunnelStopsAllActiveManagers() async throws {
            let clock = TestClock()
            let ikeManager = MockTunnelProviderManager(withBundleIdentifier: "ike", state: .ready)
            ikeManager.session = VPNSessionMock(status: .connected)
            let wgManager = MockTunnelProviderManager(withBundleIdentifier: "wg", state: .ready)
            wgManager.session = VPNSessionMock(status: .connecting)

            try await confirmation("Expected IKE manager to be prepared") { ikePrepared in
                try await confirmation("Expected WireGuard manager to be prepared") { wgPrepared in
                    try await withDependencies {
                        $0.continuousClock = clock
                        $0.vpnManagerRepository.managers = { [.ike: ikeManager, .wireGuard: wgManager] }
                        $0.vpnManagerRepository.prepareManager = { proto, _ in
                            switch proto {
                            case .ike:
                                ikePrepared()
                                return ikeManager
                            case .wireGuard:
                                wgPrepared()
                                return wgManager
                            }
                        }
                    } operation: {
                        try await PacketTunnelManager().stopTunnel()
                    }
                }
            }

            #expect(ikeManager.session.status == .disconnecting)
            #expect(wgManager.session.status == .disconnecting)
        }
    }
#endif
