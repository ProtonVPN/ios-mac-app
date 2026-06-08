//
//  Created on 06/01/2026.
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

import AsyncAlgorithms
import ConnectionShared
import Dependencies
import Domain
import Ergonomics
import IPCErgonomics
import LocalAgent
import LocalAgentIPC
import NEHelper
import NetworkExtension
import NetworkingErgonomics
import os.log
import protun
import SharedErgonomics
import VPNCoreTypes

final class ProTUNAdapter: @unchecked Sendable {
    enum Error: Swift.Error {
        case noTunFileDescriptor
        case noEventStreamAvailable
        case failedToSetToNonBlocking(FileDescriptorError)
        case noPeers
        case invalidKeys
    }

    private(set) weak var packetTunnelProvider: NEPacketTunnelProvider?

    private(set) var connection: Connection?

    let stateDelegate: ProTUNAdapterStateDelegate
    let eventDelegate: ProTUNAdapterEventDelegate

    private static let waitConnectedStateDuration: Duration = .seconds(30)
    private static let protunStateDebounceInterval: Duration = .milliseconds(250)
    private static let protunStateCheckInterval: Duration = .milliseconds(500)

    var isPacketCaptureSessionRecording: Bool {
        guard case .recording = packetCaptureSession.state else {
            return false
        }
        return true
    }

    private var packetCaptureSession: PacketCaptureSession = .init()
    private var pcapStateTask: Task<Void, Never>?

    private var localAgentCoordinator: LocalAgentCoordinator?

    private let networkPath: OSAllocatedUnfairLock<NetworkPath> = .init(uncheckedState: .init(status: .unsatisfied))
    private var localAgentTask: Task<Void, Never>?
    private var pathUpdatesTask: Task<Void, Never>?

    init(packetTunnelProvider: NEPacketTunnelProvider) {
        self.packetTunnelProvider = packetTunnelProvider
        self.stateDelegate = .init()
        self.eventDelegate = .init()
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

    func listenToPathUpdates() {
        pathUpdatesTask?.cancel()

        pathUpdatesTask = Task {
            @Dependency(\.pathMonitor) var pathMonitor

            await withTaskCancellationHandler {
                let stream = pathMonitor.subscribe()
                pathMonitor.start()
                for await newPath in stream {
                    handleNetworkPathUpdate(newPath)
                }
            } onCancel: {
                pathMonitor.stop()
            }
        }
    }

    func handleNetworkPathUpdate(_ newPath: NetworkPath) {
        Logger.adapter.info("Network path update: \(newPath, privacy: .public)")
        networkPath.withLock { $0 = newPath }
        connection?.onConnectivityChange(event: .networkSwitch)
    }

    func start(config: ProTUNConfiguration) async throws {
        Logger.adapter.info("Starting Adapter")

        let tunFd = try await prepare(with: config)
        let rawTunFd = try tunFd.dup().take()
        let localAgentSettings = LocalAgentSettings.current

        startLocalAgentRunLoop(with: localAgentSettings)

        // TODO: ProTUN: rework this so we're TOCTOU resilient
        let proTunInitialConfig = try networkPath.withLock { networkPath in
            let isNetworkAvailable = networkPath.status == .satisfied
            return try config.initialConnectionConfig(
                networkAvailable: isNetworkAvailable,
                localAgentSettings: localAgentSettings
            )
        }

        connection = .unixConnect(
            config: proTunInitialConfig,
            tunFd: rawTunFd,
            stateChangeCallback: stateDelegate,
            eventCallback: eventDelegate,
            socketFdAvailableCallback: nil,
            cache: SecurePersistentCache(keychainServiceSuffix: "user") // TODO: ProTUN: Pass a value identifying the user
        )

        try await stateDelegate.stateSource.newStream
            .debounce(for: Self.protunStateDebounceInterval)
            .when(
                willMatch: \.canCompleteStart,
                every: Self.protunStateCheckInterval,
                deadline: Self.waitConnectedStateDuration
            ) {
                Logger.adapter.debug("Adapter is started, `startTunnel` can complete")
            }
    }

    private func startLocalAgentRunLoop(with settings: LocalAgentSettings) {
        let coordinator = LocalAgentCoordinator(adapter: self, initialSettings: settings)

        localAgentTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await coordinator.start()
                }
                group.addTask {
                    let debouncedStream = coordinator.streamSource.newStream._throttle(for: .milliseconds(250))
                    for await event in debouncedStream {
                        self.handleLocalAgentCoordinatorEvent(event)
                    }
                }
            }
        }

        localAgentCoordinator = coordinator
    }

    private func handleLocalAgentCoordinatorEvent(_ event: LocalAgentCoordinator.Event) {
        switch event {
        case .forkSelectorRequest:
            // packetTunnelProvider?.reasserting = true
            Logger.localAgent.info("Sending extensionForkSelectorRequest notification")
            IPCNotifications.post(.extensionForkSelectorRequest)
        }
    }

    func stop(with reason: NEProviderStopReason) {
        Logger.adapter.info("Stopping with reason: \(reason)")

        connection?.disconnect()

        pathUpdatesTask?.cancel()
        pathUpdatesTask = nil
        localAgentTask?.cancel()
        localAgentTask = nil
    }
}

extension ProTUNAdapter {
    func handleForkSelector(_ selector: String) {
        Logger.localAgent.info("Received fork selector from app")
        connection?.provideApiForkSelector(forkSelector: selector)
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
        let eventStream = eventDelegate.eventSource.newStream
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
        networkAvailable: Bool,
        localAgentSettings: LocalAgentSettings
    ) throws(ProTUNAdapter.Error) -> InitialConnectionConfig {
        let peers = try peers.map { peer throws(ProTUNAdapter.Error) in
            try PeerInfo(from: peer)
        }

        return .init(
            peers: peers,
            networkAvailable: networkAvailable,
            pcapFile: nil,
            connectionMode: .localAgent(
                userAgent: .userAgent,
                appVersion: .appVersion,
                settings: localAgentSettings
            )
        )
    }
}

extension VpnState {
    // For now (until we have a better solution), we consider `.connectingToLocalAgent` to be enough
    // to complete the `startTunnel` lifecycle method of the Packet Tunnel Provider.
    // We need this because otherwise network calls made by the app (such as the fork selector call)
    // won't succeed if the PTP has not fully started (URLSession won't make the network call)
    var canCompleteStart: Bool {
        switch connectionState {
        case .connected, .connectingToLocalAgent:
            true
        default:
            false
        }
    }
}

// TODO: ProTUN: Properly inject this
private extension String {
    static let appVersion: String = "ios-wireguardextension@8.0.0"
    static let userAgent: String = "ProtonVPN/8.0.0 (iOS 26.4.0; iPhone16,1)"
}

extension LocalAgentSettings {
    static var current: Self {
        @Dependency(\.localAgent) var localAgentClient
        return (try? localAgentClient.settings())
            .flatMap { $0.hasValues ? LocalAgentSettings($0) : nil } ?? .default
    }

    private static let `default`: Self = .init(
        splitTcp: nil,
        netshieldLevel: nil,
        softJail: nil,
        portForwarding: nil,
        randomNat: nil,
        circumventionRouting: nil
    )

    mutating func update(with featureChanges: Set<ConnectionFeatureChange.AgentFeature>) {
        for feature in featureChanges {
            switch feature {
            case let .netShield(netShieldType):
                netshieldLevel = netShieldType.toRustNetShieldLevel
            case let .vpnAccelerator(enabled):
                splitTcp = enabled
            case let .moderateNAT(NATType):
                randomNat = NATType.flag
            case let .portForwarding(enabled):
                portForwarding = enabled
            case .safeMode:
                break // TODO: ProTUN: Remove safe mode (and bouncing) from VPNConnectionFeatures
            }
        }
    }
}

private extension NetShieldType {
    var toRustNetShieldLevel: NetshieldLevel {
        switch self {
        case .off:
            return .none
        case .level1:
            return .malwareFilter
        case .level2:
            return .adsAndMalwareFilter
        case .level3:
            assertionFailure("Not handled yet")
            return .adsAndMalwareFilter
        }
    }
}
