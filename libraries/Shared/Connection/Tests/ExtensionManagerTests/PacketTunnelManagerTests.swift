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
    @testable import ExtensionSync
    import Foundation
    import IPCDefinitions
    import IPCErgonomics
    import class NetworkExtension.NETunnelProviderProtocol
    import os
    import SharedErgonomics
    import Testing
    import VPNCoreCommon
    import VPNCoreTypes

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
                $0.extensionIPC.currentExtensionState = {
                    .init(
                        state: .connecting(peerID: nil, waitReason: .unset),
                        requestId: nil
                    )
                }
            } operation: {
                try await PacketTunnelManager().status
            }

            #expect(status == .reasserting(TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: [])))
        }

        @Test
        func treatsConnectingEchoAsDisconnectingAfterOnDemandIsDisabled() async throws {
            let providerManager = MockTunnelProviderManager(
                session: VPNSessionMock(status: .connecting),
                vpnProtocolConfiguration: NETunnelProviderProtocol(),
                isOnDemandEnabled: false,
                isEnabled: true
            )
            let config = try #require(providerManager.vpnProtocolConfiguration)
            try config.setProviderConfiguration(
                value: JSONEncoder().encode(ConnectionSpec.defaultFastest),
                forKey: "connectionSpec"
            )
            try ProTUNConfigurationCoder.encode(
                configuration: .init(preferredTransport: .udp, peers: [.mock(id: "peer-id")], dnsServers: []),
                to: config
            )
            providerManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.vpnManagerRepository.managers = { [.wireGuard: providerManager] }
                $0.extensionIPC.currentExtensionState = {
                    .init(state: .connecting(peerID: nil, waitReason: .unset), requestId: nil)
                }
            } operation: {
                try await PacketTunnelManager().status
            }

            #expect(status == .disconnecting(.init(
                connectionSpec: .defaultFastest,
                tunnelProtocol: .wireGuard,
                peerIDs: []
            )))
        }

        #if !os(tvOS)
            @Test
            func statusStreamDerivesZeroPeerKillSwitchFromAppliedConfiguration() async throws {
                let providerManager = MockTunnelProviderManager(withBundleIdentifier: "wireguard", state: .ready)
                providerManager.session = VPNSessionMock(status: .disconnected)

                let requestId = UUID()
                let config = NETunnelProviderProtocol()
                try config.setProviderConfiguration(
                    value: JSONEncoder().encode(ConnectionSpec.defaultFastest),
                    forKey: "connectionSpec"
                )
                config.setProviderConfiguration(value: requestId.uuidString, forKey: "requestID")
                config.includeAllNetworks = true
                try ProTUNConfigurationCoder.encode(
                    configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []),
                    to: config
                )
                providerManager.protocolConfiguration = config

                let (extensionStateStream, extensionStateContinuation) = AsyncStream<ExtensionStateSnapshot>.makeStream()
                defer { extensionStateContinuation.finish() }
                let previousRequestId = UUID()

                let (initial, updated) = try await withDependencies {
                    $0.continuousClock = ContinuousClock()
                    $0.vpnManagerRepository.managers = { [.wireGuard: providerManager] }
                    $0.extensionIPC.currentExtensionState = {
                        .init(
                            state: .connected(VPNSessionMock.testPeer),
                            requestId: previousRequestId
                        )
                    }
                    $0.extensionIPC.observeExtensionState = { extensionStateStream }
                } operation: {
                    var iterator = PacketTunnelManager().statusStream.makeAsyncIterator()
                    let initial = try await withTimeout(of: .seconds(1)) { await iterator.next() }

                    extensionStateContinuation.yield(.init(
                        state: .disconnected(reason: .unset),
                        requestId: requestId
                    ))
                    let updated = try await withTimeout(of: .seconds(1)) { await iterator.next() }
                    return (initial, updated)
                }

                let tunnelConfiguration = TunnelConfiguration(
                    connectionSpec: .defaultFastest,
                    tunnelProtocol: .wireGuard,
                    peerIDs: []
                )
                #expect(initial == .some(.success(.disconnected(nil))))
                #expect(updated == .some(.success(.killSwitchActive(tunnelConfiguration))))
            }
        #endif

        @Test
        func statusStreamSkipsMixedConfigurationRevisions() async throws {
            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "wireguard", state: .ready)
            providerManager.session = VPNSessionMock(status: .connected, connectedDate: .now)

            let oldRequestId = UUID()
            let config = NETunnelProviderProtocol()
            try config.setProviderConfiguration(
                value: JSONEncoder().encode(ConnectionSpec.defaultFastest),
                forKey: "connectionSpec"
            )
            config.setProviderConfiguration(value: oldRequestId.uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(
                configuration: .init(preferredTransport: .udp, peers: [.mock(id: "old-peer")], dnsServers: []),
                to: config
            )
            providerManager.protocolConfiguration = config

            let oldPeer = CurrentPeer(
                peerID: "old-peer",
                transport: .udp,
                serverExitV4: nil,
                serverExitV6: nil,
                userISP: nil,
                userIP: nil
            )
            let (stream, continuation) = AsyncStream<ExtensionStateSnapshot>.makeStream()
            defer { continuation.finish() }

            let next = try await withDependencies {
                $0.continuousClock = ContinuousClock()
                $0.vpnManagerRepository.managers = { [.wireGuard: providerManager] }
                $0.extensionIPC.currentExtensionState = {
                    .init(state: .connected(oldPeer), requestId: oldRequestId)
                }
                $0.extensionIPC.observeExtensionState = { stream }
            } operation: {
                var iterator = PacketTunnelManager().statusStream.makeAsyncIterator()
                _ = try await withTimeout(of: .seconds(1)) { await iterator.next() }

                let newRequestId = UUID()
                config.setProviderConfiguration(value: newRequestId.uuidString, forKey: "requestID")
                try ProTUNConfigurationCoder.encode(
                    configuration: .init(preferredTransport: .udp, peers: [.mock(id: "new-peer")], dnsServers: []),
                    to: config
                )

                // This combines the new saved intent with the extension's previous revision and must not escape.
                continuation.yield(.init(state: .connected(oldPeer), requestId: oldRequestId))
                continuation.yield(.init(
                    state: .connecting(peerID: "new-peer", waitReason: .unset),
                    requestId: newRequestId
                ))
                return try await withTimeout(of: .seconds(1)) { await iterator.next() }
            }

            #expect(next == .some(.success(.connecting(.init(
                connectionSpec: .defaultFastest,
                tunnelProtocol: .wireGuard,
                peerIDs: ["new-peer"]
            )))))
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
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [.mock(id: "peer-id")], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = {
                    [.ike: disconnectingManager, .wireGuard: connectedManager]
                }
                $0.extensionIPC.currentExtensionState = {
                    .init(
                        state: .connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)),
                        requestId: requestId
                    )
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
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [.mock(id: "peer-id")], dnsServers: []), to: config)
            connectedManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                $0.extensionIPC.currentExtensionState = {
                    .init(
                        state: .connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)),
                        requestId: requestId
                    )
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

        /// A pending feature-only update: the recorded request id is ahead of the extension's, but the tunnel still
        /// sits on a peer the saved configuration intends, so `.connected` wins over the in-place-save blip.
        @Test
        func returnsConnectedForPendingFeatureOnlyUpdate() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let now = Date.now

            // The `.connecting` status is the brief blip from saving NE preferences in place.
            connectedManager.session = VPNSessionMock(status: .connecting, connectedDate: now)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full

            // The recorded config is ahead of the extension (the app writes it before sending the request), but a
            // feature-only update leaves the intended peers untouched.
            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            config.setProviderConfiguration(value: UUID().uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(
                configuration: .init(preferredTransport: .udp, peers: [.mock(id: "peer-id")], dnsServers: []),
                to: config
            )
            connectedManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                $0.extensionIPC.currentExtensionState = {
                    .init(
                        state: .connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)),
                        requestId: UUID()
                    )
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

        /// A location change rewrites the intended peers, so the extension's stale `.connected` state is treated as
        /// an internal reassertion until the tunnel lands on a peer the configuration intends.
        @Test
        func returnsReassertingWhileTunnelSitsOnPeerConfigurationNoLongerIntends() async throws {
            let connectedManager = MockTunnelProviderManager(withBundleIdentifier: "connected", state: .ready)
            let now = Date.now

            connectedManager.session = VPNSessionMock(status: .connecting, connectedDate: now)
            (connectedManager.session as? VPNSessionMock)?.connectedServerID = "server-id"
            (connectedManager.session as? VPNSessionMock)?.messageHandler = MessageHandler.full

            let config = NETunnelProviderProtocol()
            let specData = try JSONEncoder().encode(ConnectionSpec.defaultFastest)
            config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
            config.setProviderConfiguration(value: UUID().uuidString, forKey: "requestID")
            try ProTUNConfigurationCoder.encode(
                configuration: .init(preferredTransport: .udp, peers: [.mock(id: "new-peer")], dnsServers: []),
                to: config
            )
            connectedManager.protocolConfiguration = config

            let status = try await withDependencies {
                $0.date = .constant(now)
                $0.vpnManagerRepository.managers = { [.wireGuard: connectedManager] }
                $0.extensionIPC.currentExtensionState = {
                    .init(
                        state: .connected(CurrentPeer(peerID: "peer-id", transport: .udp, serverExitV4: nil, serverExitV6: nil, userISP: nil, userIP: nil)),
                        requestId: UUID()
                    )
                }
            } operation: {
                try await PacketTunnelManager().status
            }

            #expect(status == .reasserting(TunnelConfiguration(connectionSpec: .defaultFastest, tunnelProtocol: .wireGuard, peerIDs: ["peer-id"])))
        }

        /// The update must be recorded in NE preferences before the provider message goes out, so the saved requestId
        /// always leads what the extension reports back.
        @Test
        func recordsConfigurationUpdateBeforeSendingProviderMessage() async throws {
            let providerManager = MockTunnelProviderManager(withBundleIdentifier: "wg")
            let update = ConnectionUpdate(netShield: .off)
            let recorded = OSAllocatedUnfairLock(initialState: false)

            (providerManager.session as? VPNSessionMock)?.messageHandler = { _, _ in
                #expect(recorded.withLock { $0 }, "The update must be recorded before the message is sent")
                return .init(payload: .ack)
            }

            _ = try await withDependencies {
                $0.vpnManagerRepository.prepareManager = { proto, operation in
                    #expect(proto == .wireGuard)
                    guard case let .update(recordedUpdate) = operation else {
                        Issue.record("Expected an update operation, got \(operation)")
                        return providerManager
                    }
                    #expect(recordedUpdate.id == update.id)
                    recorded.withLock { $0 = true }
                    return providerManager
                }
            } operation: {
                try await PacketTunnelManager().sendProTUN(request: .init(payload: .updateConfiguration(update)))
            }

            #expect(recorded.withLock { $0 })
        }

        #if !os(tvOS)
            /// The `.update` operation is the app-side half of a configuration update: it records the request id and the
            /// OS-enforced properties into the provider configuration the repository is about to save.
            @Test
            func updateOperationRecordsChangesInProviderConfiguration() async throws {
                var manager: TunnelProviderManager = MockTunnelProviderManager(withBundleIdentifier: "wireguard")
                let config = NETunnelProviderProtocol()
                config.providerConfiguration = [:]
                manager.protocolConfiguration = config

                let update = ConnectionUpdate(killSwitch: true, allowLAN: true)
                try await ManagerConfigurator.wireGuardConfigurator.configure(&manager, for: .update(update))

                #expect(manager.vpnProtocolConfiguration?.requestId == update.id)
                #expect(manager.vpnProtocolConfiguration?.includeAllNetworks == true)
                #expect(manager.vpnProtocolConfiguration?.excludeLocalNetworks == false)
            }
        #endif

        /// Requested Local Agent features are part of the write-ahead record, so a quiesced request id implies the
        /// stored configuration reflects them.
        @Test
        func updateOperationRecordsAgentFeaturesInProviderConfiguration() async throws {
            var manager: TunnelProviderManager = MockTunnelProviderManager(withBundleIdentifier: "wireguard")
            let config = NETunnelProviderProtocol()
            config.providerConfiguration = [:]
            try ProTUNConfigurationCoder.encode(configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []), to: config)
            manager.protocolConfiguration = config

            let update = ConnectionUpdate(netShield: .level1, vpnAccelerator: true, moderateNAT: .moderateNAT, portForwarding: true)
            try await ManagerConfigurator.wireGuardConfigurator.configure(&manager, for: .update(update))

            let recorded = try #require(manager.vpnProtocolConfiguration)
            let stored = try ProTUNConfigurationCoder.decode(from: recorded)
            #expect(recorded.requestId == update.id)
            #expect(stored.netShieldLevel == NetShieldType.level1.rawValue)
            #expect(stored.vpnAccelerator == true)
            #expect(stored.portForwarding == true)
            #expect(stored.randomNat == NATType.moderateNAT.flag)
        }

        @Test
        func updateOperationFailsWithoutProviderConfiguration() async {
            var manager: TunnelProviderManager = MockTunnelProviderManager(
                session: VPNSessionMock(status: .disconnected),
                vpnProtocolConfiguration: nil,
                isOnDemandEnabled: false,
                isEnabled: true
            )

            do {
                try await ManagerConfigurator.wireGuardConfigurator.configure(&manager, for: .update(.init(netShield: .off)))
                #expect(Bool(false), "Expected a missing provider configuration to fail")
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

    private extension ProTUNConfiguration.Peer {
        static func mock(id: String) -> Self {
            .init(
                id: id,
                serverIP: "10.0.0.1",
                serverPublicKey: "public-key",
                udpPorts: [51820],
                tcpPorts: [],
                tlsPorts: [],
                priority: 0,
                exitLabel: nil
            )
        }
    }
#endif
