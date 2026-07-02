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
import ExtensionSync
import IPCDefinitions
import IPCErgonomics
import NetworkExtension
import NetworkingErgonomics
import OSLog
import PMLogger
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
        case missingUserID
        case missingConfiguration
        case noConnection
    }

    private(set) weak var packetTunnelProvider: NEPacketTunnelProvider?

    private(set) var connection: Connection?

    let stateDelegate: ProTUNAdapterStateDelegate
    let eventDelegate: ProTUNAdapterEventDelegate

    private static let waitConnectedStateDuration: Duration = .seconds(30)
    private static let protunStateDebounceInterval: Duration = .milliseconds(250)
    private static let protunStateCheckInterval: Duration = .milliseconds(500)

    var isPacketCaptureSessionRecording: Bool {
        switch packetCaptureSession.state {
        case .recording:
            true
        default:
            false
        }
    }

    private var packetCaptureSession: PacketCaptureSession = .init()
    private var pcapStateTask: Task<Void, Never>?

    private var localAgentCoordinator: LocalAgentCoordinator?

    private let networkPath: OSAllocatedUnfairLock<NetworkPath> = .init(uncheckedState: .init(
        status: .unsatisfied,
        gateways: [],
        supportsIPv4: false,
        supportsIPv6: false
    ))

    private var localAgentTask: Task<Void, Never>?
    private var pathUpdatesTask: Task<Void, Never>?

    /// Serializes every change to the session configuration.
    private let configurationStore: ConfigurationStore

    var currentRequestId: UUID? {
        get async { await configurationStore.requestId }
    }

    @Dependency(\.extensionIPCServer) var extensionIPCServer
    private let signposter = OSSignposter(logger: .adapter)

    init(packetTunnelProvider: NEPacketTunnelProvider) {
        self.packetTunnelProvider = packetTunnelProvider
        self.stateDelegate = .init()
        self.eventDelegate = .init()

        let providerConfig = packetTunnelProvider.protocolConfiguration as? NETunnelProviderProtocol
        self.configurationStore = ConfigurationStore(initial: providerConfig?.requestId)
    }

    /// Acknowledges the app's receipt of the last reported error. If the error still pertains to the current request,
    /// clear the error region and update the IPCConnectionData to include the error ID so that the connection layer
    /// can properly quiesce. If the ack's id doesn't match the request ID that's currently in flighht, ignore it.
    func acknowledgeError(_ errorId: UUID) async {
        guard await currentRequestId == errorId else {
            Logger.adapter.info("Ignoring stale error ack \(errorId.uuidString, privacy: .public)")
            return
        }
        extensionIPCServer.restampConnectionData(errorId)
        extensionIPCServer.clearError()
    }

    func prepare(with config: ProTUNConfiguration) async throws -> FileDescriptor {
        Logger.adapter.info("Preparing...")

        // VPNAPPL-3344 For multi-peer support, it's likely that we will need to set the
        // server IP address to something other than the address of the first peer in the list
        if let peer = config.peers.first {
            try await setNetworkSettings(serverIpAddress: peer.serverIP)
        } else {
            // Preparing the Adapter without any peer is allowed
            // Just generate the network settings intercepting all possible routes
            Logger.adapter.info("Preparing in zero-peer killswitch mode (no peers)")
            try await setNetworkSettings(serverIpAddress: nil)
        }

        return try setupTunnelDescriptor()
    }

    func listenToPathUpdates() {
        pathUpdatesTask?.cancel()

        pathUpdatesTask = Task {
            @Dependency(\.pathMonitor) var pathMonitor

            await withTaskCancellationHandler {
                let stream = pathMonitor.subscribe()
                pathMonitor.start()

                var currentPath = networkPath.withLock { $0 }
                for await newPath in stream {
                    handleNetworkPathUpdate(old: currentPath, new: newPath)
                    currentPath = newPath
                    networkPath.withLock { $0 = newPath }
                }
            } onCancel: {
                pathMonitor.stop()
            }
        }
    }

    func handleNetworkPathUpdate(old: NetworkPath, new: NetworkPath) {
        let event: ConnectivityEvent? = switch (old.isUsable, new.isUsable) {
        case (false, true): .up
        case (true, false): .down
        // avoid flapping connectivity events if the status hasn't meaningfully changed
        case (false, false): nil
        case (true, true): old == new ? nil : .networkSwitch
        }

        guard let event else {
            Logger.adapter.debug("Ignoring connectivity event: \(new, privacy: .public)")
            return
        }

        Logger.adapter.info("Network path update: \(new, privacy: .public) (now \(event))")
        connection?.onConnectivityChange(event: event)
    }

    func start(config: Configuration) async throws {
        // Measures the whole start sequence
        let signpostID = signposter.makeSignpostID()
        let startState = signposter.beginInterval("Start Tunnel", id: signpostID)
        defer { signposter.endInterval("Start Tunnel", startState) }

        Logger.adapter.info("Starting Adapter")
        extensionIPCServer.zeroAll()

        let tunFd = try await prepare(with: config.proTUN)
        signposter.emitEvent("Tunnel prepared", id: signpostID)

        let rawTunFd = try tunFd.dup().take()

        // Initial Local Agent settings come from the app, while the extension manages all protocol settings
        // once it's running.
        let localAgentSettings = LocalAgentSettings(config.proTUN)

        startLocalAgentRunLoop()
        signposter.emitEvent("Local agent run loop started", id: signpostID)

        // TODO: ProTUN: rework this so we're TOCTOU resilient
        let proTunInitialConfig = try networkPath.withLock { networkPath in
            let isNetworkAvailable = networkPath.status == .satisfied
            return try initialConnectionConfig(
                proTUNConfig: config.proTUN,
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
            cache: SecurePersistentCache(userID: config.userID)
        )
        signposter.emitEvent("Connection established", id: signpostID)

        if config.proTUN.hasZeroPeers {
            // Lib connection object will never transition to connected with 0 peers so completing immediately
            // (this allows starts of the extension via onDemand rules or after any termination to start anyway)
            Logger.adapter.info("Adapter is started in 0 peers mode, `startTunnel` can complete")
            // Re-publish the zero-peer KS flag in case we're resuming from a persisted config after an extension crash.
            publishZeroPeerMode(active: true)
        } else {
            try await stateDelegate.stateSource.newStream
                .debounce(for: Self.protunStateDebounceInterval)
                .when(
                    willMatch: \.canCompleteStart,
                    every: Self.protunStateCheckInterval,
                    deadline: Self.waitConnectedStateDuration
                ) {
                    // Reached `.connected` / `.connectingToLocalAgent`: the tunnel is up.
                    self.signposter.emitEvent("Connected", id: signpostID)
                    Logger.adapter.debug("Adapter is started, `startTunnel` can complete")
                }
        }
    }

    private func startLocalAgentRunLoop() {
        let coordinator = LocalAgentCoordinator(adapter: self)

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
            Logger.localAgent.info("Sending forkSelectorRequest tunnel command")
            extensionIPCServer.sendCommand(.forkSelectorRequest)
        }
    }

    func stop(with reason: NEProviderStopReason) {
        Logger.adapter.info("Stopping with reason: \(reason)")

        if isPacketCaptureSessionRecording {
            handlePacketCaptureInterruption(reason: .connectionTerminated)
        }

        connection?.disconnect()

        pathUpdatesTask?.cancel()
        pathUpdatesTask = nil
        localAgentTask?.cancel()
        localAgentTask = nil

        // Clear the shared memory regions just before stopping.
        extensionIPCServer.zeroAll()
    }
}

// MARK: - Tunnel bringup + configuration

extension ProTUNAdapter {
    func handleForkSelector(_ selector: String, cookieName: String, cookieValue: String) {
        Logger.localAgent.info("Received fork selector from app")
        let forkSelectorInfo = ForkSelectorInfo(
            selector: selector,
            cookies: .init(cookies: [.init(name: cookieName, value: cookieValue)])
        )
        connection?.provideApiForkSelector(forkSelectorInfo: forkSelectorInfo)
    }

    func handlePeersUpdate(_ newPeers: [PeerInfo]) throws(ProTUNAdapter.Error) {
        guard let connection else { throw .noConnection }
        connection.updatePeers(peers: newPeers)
    }

    func publishZeroPeerMode(active: Bool) {
        extensionIPCServer.setZeroPeerKillSwitchActive(active)
    }

    /// Single entry point for updating LocalAgentSettings.
    func applyLocalAgentSettings(_ settings: LocalAgentSettings) throws(ProTUNAdapter.Error) {
        guard let connection else { throw .noConnection }
        connection.updateLocalAgentSettings(settings: settings)
    }

    func enqueueConfigurationUpdate(_ update: ConnectionUpdate) async {
        await configurationStore.apply(update, adapter: self)
    }

    func whileReasserting<T, E: Swift.Error>(_ closure: () async throws(E) -> T) async throws(E) -> T {
        packetTunnelProvider?.reasserting = true
        defer { packetTunnelProvider?.reasserting = false }
        return try await closure()
    }
}

// MARK: - Network setup

extension ProTUNAdapter {
    func setNetworkSettings(serverIpAddress: String?) async throws {
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
            self.connection?.startPacketCapture(pcapFile: .init(file: file, maxBytes: UInt64(maxBytes)))
        } stateStream: { stream in
            listenToPacketCaptureUpdates(with: stream)
        }
    }

    @discardableResult
    func stopPacketCapture(reason: PacketCaptureInterruptionReason) -> URLWithSize? {
        guard let (pcapFileURL, duration, fileSize) = packetCaptureSession.stop() else { return nil }
        switch reason {
        case .unknown, .timerHit, .explicitStop:
            connection?.stopPacketCapture()
        // We don't want to call stopCaptureAgain if it was already stopped
        case .storageLimitHit, .connectionTerminated:
            break
        }

        let formattedDuration = Duration.seconds(duration).formatted(.units(allowed: [.minutes, .seconds]))
        Logger.adapter.info("Capture lasted \(formattedDuration, privacy: .public) and file size is \(fileSize) bytes")
        pcapStateTask?.cancel()
        pcapStateTask = nil
        return .init(url: pcapFileURL, size: fileSize)
    }

    private func handlePacketCaptureInterruption(reason: PacketCaptureInterruptionReason) {
        stopPacketCapture(reason: reason)

        @Dependency(\.pcapSharedPropertyUpdater) var pcapSharedPropertyUpdater
        pcapSharedPropertyUpdater.finishPCAPSession(reason: reason)

        IPCNotifications.postState(.pcapInterrupted, state: reason)
    }

    struct Configuration {
        let userID: String
        let proTUN: ProTUNConfiguration
    }
}

// MARK: - Helpers

extension ProTUNConfiguration {
    var hasZeroPeers: Bool {
        peers.isEmpty
    }
}

extension ProTUNAdapter {
    func initialConnectionConfig(
        proTUNConfig: ProTUNConfiguration,
        networkAvailable: Bool,
        localAgentSettings: LocalAgentSettings
    ) throws(ProTUNAdapter.Error) -> InitialConnectionConfig {
        // Restrict transports ProTUN will attempt to connect with by constraining the peers
        let peers = try proTUNConfig.peers
            .compactMap { $0.constrained(to: proTUNConfig.preferredTransport) }
            .map { peer throws(ProTUNAdapter.Error) in
                try PeerInfo(from: peer)
            }
        @Dependency(\.appInfo) var appInfo

        return .init(
            peers: peers,
            networkAvailable: networkAvailable,
            pcapFile: nil,
            connectionMode: .localAgent(
                userAgent: appInfo.userAgent,
                appVersion: appInfo.appVersion,
                settings: localAgentSettings,
                muonEnv: .prod
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
