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

import Domain
import NEHelper
import NetworkExtension
import NetworkingErgonomics
import os.log

#if os(iOS)
    private final class ProTUNAdapterStateDelegate: StateChangedCallback {
        func onStateChanged(state: State) {
            Logger.adapter.info("Internal ProTUN state changed: \(state, privacy: .public)")
        }
    }

    final class ProTUNAdapter: @unchecked Sendable {
        enum Error: Swift.Error {
            case noTunFileDescriptor
            case failedToSetToNonBlocking(FileDescriptorError)
            case invalidKeys
        }

        private(set) weak var packetTunnelProvider: NEPacketTunnelProvider?

        private var connection: Connection?
        private let stateDelegate: ProTUNAdapterStateDelegate

        init(packetTunnelProvider: NEPacketTunnelProvider) {
            self.packetTunnelProvider = packetTunnelProvider
            self.stateDelegate = .init()
        }

        func prepare(with data: ProTUNMinimalData) async throws -> FileDescriptor {
            Logger.adapter.info("Preparing...")
            try await setNetworkSettings(serverIpAddress: data.serverIpAddress)
            return try setupTunnelDescriptor()
        }

        func start(data: ProTUNMinimalData) async throws {
            Logger.adapter.info("Starting Adapter")
            let tunFd = try await prepare(with: data)
            let initialConfig = try data.initialConnectionConfig
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

    extension ProTUNMinimalData {
        private var initialPeer: PeerInfo {
            get throws(ProTUNAdapter.Error) {
                guard let serverPublicKeyData = Data(base64Encoded: serverPublicKey) else {
                    throw .invalidKeys
                }
                return .init(
                    peerId: UUID().uuidString,
                    serverIp: serverIpAddress,
                    serverPublicKey: serverPublicKeyData,
                    udpPorts: [51820],
                    tcpPorts: [],
                    tlsPorts: [],
                    priority: 1
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
