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

#if os(iOS) && DEBUG
    import Domain
    import Ergonomics
    import IPCErgonomics
    import NEHelper
    import NetworkExtension
    import NetworkingErgonomics
    import os.log
    import SharedErgonomics
    import enum VPNCoreCommon.ProTUNConfigurationCoder
    import struct VPNCoreTypes.ProTUNConfiguration

    final class ProTUNAdapter: @unchecked Sendable {
        enum Error: Swift.Error {
            case noTunFileDescriptor
            case noEventStreamAvailable
            case failedToSetToNonBlocking(FileDescriptorError)
            case noPeers
            case invalidKeys
        }

        private(set) weak var packetTunnelProvider: NEPacketTunnelProvider?

        private static let waitConnectedStateDuration: Duration = .seconds(30)

        var isPacketCaptureSessionRecording: Bool {
            guard case .recording = packetCaptureSession.state else {
                return false
            }
            return true
        }

        private var connection: Connection?
        private var packetCaptureSession: PacketCaptureSession = .init()
        private var pcapStateTask: Task<Void, Never>?

        private var eventDelegate: ProTUNAdapterEventDelegate?

        init(packetTunnelProvider: NEPacketTunnelProvider) {
            self.packetTunnelProvider = packetTunnelProvider
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

        func start(
            config: ProTUNConfiguration,
            privateKey: String,
            stateDelegate: ProTUNAdapterStateDelegate,
            eventDelegate: ProTUNAdapterEventDelegate
        ) async throws {
            Logger.adapter.info("Starting Adapter")

            self.eventDelegate = eventDelegate

            let tunFd = try await prepare(with: config)
            let initialConfig = try config.initialConnectionConfig(withPrivateKey: privateKey)
            let rawTunFd = try tunFd.dup().take()

            connection = .unixConnect(
                config: initialConfig,
                tunFd: rawTunFd,
                stateChangeCallback: stateDelegate,
                socketFdAvailableCallback: nil,
                eventCallback: eventDelegate
            )

            try await stateDelegate.stateSource.newStream.when(
                willMatch: \.isConnected,
                every: .milliseconds(500),
                deadline: Self.waitConnectedStateDuration
            ) {
                Logger.adapter.debug("Adapter transitioned to .connected")
            }
        }

        func stop(with reason: NEProviderStopReason) async {
            Logger.adapter.info("Stopping with reason: \(reason)")
        }
    }

    // MARK: - Network setup

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

    // MARK: - Packet Capture

    extension ProTUNAdapter {
        func listenToPacketCaptureUpdates(with stream: AsyncStream<PacketCaptureSession.State>) {
            pcapStateTask = Task {
                for await state in stream {
                    Logger.adapter.info("Packet Capture is now in state: \(state, privacy: .public)")

                    switch state {
                    case .timerHit:
                        handlePacketCaptureInterruption(reason: .timerHit)
                    case .maxFileSizeHit:
                        handlePacketCaptureInterruption(reason: .storageLimitHit)
                    case .idle, .recording, .finished:
                        break
                    }
                }
            }
        }

        @discardableResult
        func startPacketCapture() throws -> URL {
            guard let eventStream = eventDelegate?.eventSource.newStream else {
                throw Error.noEventStreamAvailable
            }
            return try packetCaptureSession.start(with: eventStream) { fileURL, maxBytes in
                let file: PcapFile = .path(path: fileURL.absolutePath, mode: .overwrite)
                self.connection?.startPacketCapture(pcapFile: .init(file: file, maxBytes: maxBytes))
            } stateStream: { stream in
                listenToPacketCaptureUpdates(with: stream)
            }
        }

        @discardableResult
        func stopPacketCapture(reason: PacketCaptureInterruptionReason) throws -> (URL, Int64) {
            let (pcapFileURL, duration, fileSize) = try packetCaptureSession.stop {
                switch reason {
                case .unknown, .timerHit, .explicitStop:
                    self.connection?.stopPacketCapture()
                // We don't want to call stopCaptureAgain if it was already stopped because file size limit was hit
                case .storageLimitHit:
                    break
                }
            }
            let formattedDuration = Duration.seconds(duration).formatted(.units(allowed: [.minutes, .seconds]))
            Logger.adapter.info("Capture lasted \(formattedDuration, privacy: .public) and file size is \(fileSize) bytes")
            pcapStateTask?.cancel()
            pcapStateTask = nil
            return (pcapFileURL, fileSize)
        }

        private func handlePacketCaptureInterruption(reason: PacketCaptureInterruptionReason) {
            do {
                try stopPacketCapture(reason: reason)
            } catch {
                connection?.stopPacketCapture()
            }
            IPCNotifications.postState(.pcapInterrupted, state: reason)
        }
    }

    // MARK: - Helpers

    extension ProTUNConfiguration {
        func initialConnectionConfig(
            withPrivateKey clientPrivateKey: String
        ) throws(ProTUNAdapter.Error) -> InitialConnectionConfig {
            guard let clientPrivateKeyData = Data(base64Encoded: clientPrivateKey) else {
                throw .invalidKeys
            }
            let peers = try peers.map { peer throws(ProTUNAdapter.Error) in
                try PeerInfo(from: peer)
            }
            return .init(
                wgPrivateKey: clientPrivateKeyData,
                peers: peers,
                networkAvailable: true,
                pcapFile: nil
            )
        }
    }

    extension State: CustomStringConvertible {
        var isConnected: Bool {
            switch self {
            case .connected:
                true
            default:
                false
            }
        }

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
