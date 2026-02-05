//
//  Created on 06/01/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
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

import ConnectionShared
import Domain
import NEHelper
import NetworkExtension
import NetworkingErgonomics
import os.log

#if os(iOS)
    private final class ProTUNAdapterStateDelegate: StateChangedCallback, @unchecked Sendable {
        var stateChangeHandler: ((State) -> Void)?

        func onStateChanged(state: State) {
            Logger.adapter.info("Internal ProTUN state changed: \(state, privacy: .public)")
            stateChangeHandler?(state)
        }
    }

    final class ProTUNAdapter: @unchecked Sendable {
        enum Error: Swift.Error {
            case noTunFileDescriptor
            case failedToSetToNonBlocking(FileDescriptorError)
            case noPeers
            case invalidKeys
        }

        private(set) weak var packetTunnelProvider: NEPacketTunnelProvider?

        private var connection: Connection?
        private(set) var connectionState: State
        private let stateDelegate: ProTUNAdapterStateDelegate

        init(packetTunnelProvider: NEPacketTunnelProvider) {
            self.packetTunnelProvider = packetTunnelProvider
            self.stateDelegate = .init()
            self.connectionState = .disconnected(error: nil)

            stateDelegate.stateChangeHandler = { [weak self] in self?.connectionState = $0 }
        }

        func prepare(with config: ProTUNConfiguration) async throws -> FileDescriptor {
            Logger.adapter.info("Preparing...")
            // VPNAPPL-3344 For multi-peer support, it's likely that we will need to set the
            // server IP address to something other than the address of the first peer in the list
            guard let peer = config.peers.first else {
                Logger.adapter.error("Configuration does not contain any peers")
                throw Error.noPeers
            }
            try await setNetworkSettings(serverIpAddress: peer.serverIP)
            return try setupTunnelDescriptor()
        }

        func start(config: ProTUNConfiguration) async throws {
            Logger.adapter.info("Starting Adapter")
            let tunFd = try await prepare(with: config)
            let initialConfig = try config.initialConnectionConfig
            let rawTunFd = try tunFd.dup().take()
            connection = .unixConnect(
                config: initialConfig,
                tunFd: rawTunFd,
                stateChangeCallback: stateDelegate,
                socketFdAvailableCallback: nil
            )
        }

        func stop(with reason: NEProviderStopReason) async {
            Logger.adapter.info("Stopping with reason: \(reason)")
        }
    }

    extension ProTUNAdapter {
        func setNetworkSettings(serverIpAddress: String) async throws {
            let networkSettings = SettingsGenerator.settings(excludingRoute: serverIpAddress)
            try await packetTunnelProvider?.setTunnelNetworkSettings(networkSettings)
        }

        func setupTunnelDescriptor() throws(Error) -> FileDescriptor {
            let tunFd = packetTunnelProvider.flatMap { FileDescriptor.tunFileDescriptor(for: $0) }
            guard let tunFd else {
                throw .noTunFileDescriptor
            }
            do {
                try tunFd.setNonBlocking(true)
            } catch {
                throw .failedToSetToNonBlocking(error)
            }
            return tunFd
        }
    }

    extension ProTUNConfiguration {
        private var initialPeer: PeerInfo {
            get throws(ProTUNAdapter.Error) {
                guard let peer = peers.first else {
                    throw .noPeers
                }
                guard let serverPublicKeyData = Data(base64Encoded: peer.serverPublicKey) else {
                    throw .invalidKeys
                }
                return .init(
                    peerId: peer.id,
                    serverIp: peer.serverIP,
                    serverPublicKey: serverPublicKeyData,
                    udpPorts: peer.udpPorts,
                    tcpPorts: peer.tcpPorts,
                    tlsPorts: peer.tlsPorts,
                    priority: Int32(peer.priority)
                )
            }
        }

        var initialConnectionConfig: InitialConnectionConfig {
            get throws(ProTUNAdapter.Error) {
                guard let clientPrivateKeyData = Data(base64Encoded: clientPrivateKey) else {
                    throw .invalidKeys
                }
                let peer = try initialPeer
                return .init(
                    wgPrivateKey: clientPrivateKeyData,
                    peers: [peer],
                    networkAvailable: true
                )
            }
        }
    }

    extension State: CustomStringConvertible {
        public var description: String {
            switch self {
            case let .disconnected(error):
                ".disconnected(\(error.stringForLog))"
            case .connecting:
                ".connecting"
            case .waitingForAction:
                ".waitingForAction"
            case .connected:
                ".connected"
            }
        }
    }
#endif
