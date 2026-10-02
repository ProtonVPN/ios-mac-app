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
import Darwin
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
import Queue
import SharedErgonomics
import Sharing
import VPNCoreCommon
import VPNCoreTypes

actor ProTUNAdapter {
    enum State {
        case idle
        case starting
        case running
    }

    enum Error: Swift.Error {
        case invalidState
        case noTunFileDescriptor
        case failedToSetToNonBlocking(FileDescriptorError)
        case invalidKeys
        case missingUserID
        case missingConfiguration
        case noConnection
        case sessionCleared
    }

    private(set) var state: State = .idle

    weak let packetTunnelProvider: NEPacketTunnelProvider?

    let stateDelegate: ProTUNAdapterStateDelegate
    let eventDelegate: ProTUNAdapterEventDelegate

    var currentRequestId: UUID? {
        get async { await configurationStore.requestId }
    }

    var currentPeer: PeerConnectionInfo? {
        get async { await stateDelegate.currentState?.connectionState.currentPeer }
    }

    private static let waitConnectedStateDuration: Duration = .seconds(30)

    /// A sleep this long or longer will result in ProTUN expiring the transport's handshake keys and NAT mappings,
    /// causing a "reconnect" of sorts. A sleep shorter than this interval implies the connection is likely still fine.
    private static let transportExpiryThreshold: TimeInterval = 30

    private var connection: Connection?

    /// The tunnel's utun file descriptor, saved here for the duration of the tunnel session. Every time startTunnel
    /// gets called, we hand a duplicate file descriptor to ProTUN, which gets closed if/when ProTUN disconnects through
    /// a call to `stop(reason:)`. Keeping the original lets us fully restart the tunnel by creating another duplicate.
    private(set) var tunnelFd: CInt?

    private let startQueue = AsyncQueue()

    @Dependency(\.extensionIPCServer) private var extensionIPCServer
    @Dependency(\.date) private var date
    #if os(macOS)
        @Dependency(\.packetFilterCoordinator) var packetFilterCoordinator
    #endif

    /// Serializes every change to the session configuration.
    private let configurationStore: ConfigurationStore

    private var pcapDurationTask: Task<Void, Never>?

    private var networkPath: NetworkPath = .initial

    private var didSleepOn: Date?

    private var localAgentTask: Task<Void, Never>?
    private var pathUpdatesTask: Task<Void, Never>?
    private var firstUnlockTask: Task<Void, Never>?

    private let signposter = OSSignposter(logger: .adapter)

    init(packetTunnelProvider: UncheckedSendable<NEPacketTunnelProvider>) {
        self.packetTunnelProvider = packetTunnelProvider.value
        self.stateDelegate = .init()
        self.eventDelegate = .init()

        let providerConfig = packetTunnelProvider.protocolConfiguration as? NETunnelProviderProtocol
        self.configurationStore = ConfigurationStore(initial: providerConfig?.requestId)
    }

    /// Prepares the tunnel network settings according to the ProTUN configuration on the protocol settings.
    func prepare(with config: ProTUNConfiguration) async throws {
        Logger.adapter.info("Preparing...")
        if config.peers.isEmpty {
            // Preparing the Adapter without any peer is allowed
            // We will just generate the network settings intercepting all possible routes
            Logger.adapter.info("Preparing in zero-peer killswitch mode (no peers)")
        }
        try await setNetworkSettings(excludingRoutes: config.uniquePeerAddresses, dnsServers: config.dnsServers)
    }

    /// - Parameter activationAttemptId: `nil` when the tunnel start was requested by the system (through an on-demand
    /// rule, or user action in VPN Settings or the Control Centre). This can happen after the user has signed out
    func start(config: Configuration, activationAttemptId: String? = nil) async throws {
        if activationAttemptId == nil, sessionWasCleared(for: config) {
            Logger.adapter.info("ProTUN session state was cleared on sign-out, start refused")
            throw Error.sessionCleared
        }

        let task = startQueue.addOperation { [weak self] in
            guard let self else { throw CancellationError() }
            try await _start(config: config)
        }

        try await task.value

        guard case .running = state else {
            throw CancellationError()
        }
    }

    private func sessionWasCleared(for config: Configuration) -> Bool {
        if config.proTUN.peers.isEmpty {
            // Kill switch edge case: we should continue blackholing
            return false
        }

        if config.isLegacyFallback {
            // Legacy edge case: no session information yet because we're replacing a WG Go tunnel
            return false
        }
        return SecurePersistentCache.wasSessionCleared(for: config.userID)
    }

    private func _start(config: Configuration) async throws {
        try Task.checkCancellation()

        guard case .idle = state else {
            throw Error.invalidState
        }

        state = .starting
        defer {
            if case .starting = state {
                stop(with: .providerFailed)
            }
        }

        // Measures the whole start sequence
        let signpostID = signposter.makeSignpostID()
        let startState = signposter.beginInterval("Start Tunnel", id: signpostID)
        defer { signposter.endInterval("Start Tunnel", startState) }

        Logger.adapter.info("Starting Adapter")

        let cache = SecurePersistentCache(userID: config.userID)

        extensionIPCServer.zeroAll()

        let pcapFile = configuredPacketCapture(for: config)

        // Published before ProTUN can open the file, so the app can distinguish between `.stopped` and `.starting`.
        if pcapFile != nil {
            extensionIPCServer.publishPacketCapture(.starting)
        }

        listenToPathUpdates()
        listenForFirstUnlock()

        try await prepare(with: config.proTUN)
        if tunnelFd == nil {
            tunnelFd = try setupTunnelDescriptor().take()
        }
        try Task.checkCancellation()
        signposter.emitEvent("Tunnel prepared", id: signpostID)

        guard let tunnelFd, case let rawTunFd = dup(tunnelFd), rawTunFd >= 0 else {
            throw Error.noTunFileDescriptor
        }
        #if os(macOS)
            // Now that the descriptor and the saved configuration are both known, update the filter policy here so the
            // tunnel doesn't come up before the packet filter is active.
            refreshPacketFilterPolicy()
        #endif

        // Initial Local Agent settings come from the app, while the extension manages all protocol settings once it's
        // running.
        let localAgentSettings = LocalAgentSettings(config.proTUN)

        startLocalAgentRunLoop()
        signposter.emitEvent("Local agent run loop started", id: signpostID)

        let proTunInitialConfig = try initialConnectionConfig(
            proTUNConfig: config.proTUN,
            networkAvailable: networkPath.isUsable,
            localAgentSettings: localAgentSettings,
            pcapFile: pcapFile
        )

        #if os(iOS)
            if config.isLegacyFallback {
                // Recover the session state that the WireGuard extension left in the keychain, so a tunnel adopted
                // from it can reuse the old session in case the app is not ready to respond to fork selector requests.
                try LegacyKeychainMigration.migrateIfNeeded(into: cache, config: config)
            }
        #endif

        connection = .unixConnect(
            config: proTunInitialConfig,
            tunFd: rawTunFd,
            stateChangeCallback: stateDelegate,
            eventCallback: eventDelegate,
            socketFdAvailableCallback: nil,
            cache: cache
        )

        signposter.emitEvent("Connection established", id: signpostID)

        if pcapFile != nil {
            reportPacketCaptureWhenConnected()
        }

        if config.proTUN.peers.isEmpty {
            // Lib connection object will never transition to connected with 0 peers so completing immediately
            // (this allows starts of the extension via onDemand rules or after any termination to start anyway)
            Logger.adapter.info("Adapter is started in 0 peers mode, `startTunnel` can complete")
            await extensionIPCServer.publishExtensionState(
                .disconnected(reason: .unset),
                currentRequestId
            )
        } else {
            do {
                try await stateDelegate.whenState(\.canCompleteStart, timeout: .duration(Self.waitConnectedStateDuration))
                // Reached `.connected` / `.connectingToLocalAgent`: the tunnel is up.
                signposter.emitEvent("Connected", id: signpostID)
                Logger.adapter.debug("Adapter is started, `startTunnel` can complete")
            } catch .timeout {
                // Complete the start anyway: ProTUN keeps retrying in the background, and the app follows the attempts
                // on the state channel rather than failing the whole tunnel here.
                Logger.adapter.info("Tunnel start deadline passed while still connecting, completing anyway")
            } catch {
                // The state stream ended, so the extension is going down before the tunnel reported connected.
                throw CancellationError()
            }
        }

        try Task.checkCancellation()

        state = .running
    }

    /// Ends the tunnel session as part of the Network Extension lifecycle (cancels queued operations, tears the
    /// connection down, and closes the tunnel file descriptor).
    func stop(with reason: NEProviderStopReason) {
        Logger.adapter.info("Stopping with reason: \(reason, privacy: .public)")

        startQueue.cancelAllPendingTasks()
        _stop()

        // System is tearing down the utun interface, close and set it to nil.
        if let tunnelFd {
            close(tunnelFd)
            self.tunnelFd = nil
        }
        #if os(macOS)
            refreshPacketFilterPolicy()
        #endif
    }

    /// The symmetric case of `_stop`, where we want to disconnect ProTUN outside of the Network Extension lifecycle.
    /// Releases everything created by a connection without cancelling everything on the queue, since if we're
    /// restarting (e.g. due to device unlock) this would mean cancelling ourselves as well.
    private func _stop() {
        cancelPacketCaptureDurationLimit()

        connection?.disconnectAndWait()
        connection = nil

        pathUpdatesTask?.cancel()
        pathUpdatesTask = nil
        localAgentTask?.cancel()
        localAgentTask = nil
        firstUnlockTask?.cancel()
        firstUnlockTask = nil
        didSleepOn = nil

        // Clear the shared memory regions just before stopping.
        extensionIPCServer.zeroAll()

        state = .idle
    }

    private func restartIfNotConnected() async {
        guard connection != nil, await stateDelegate.currentState?.isConnected != true else { return }
        guard let protocolConfiguration = packetTunnelProvider?.protocolConfiguration else { return }
        Logger.adapter.info("Restarting the connection (we were not previously connected)...")
        do {
            let config = try Configuration(decoding: protocolConfiguration)
            try await reasserting(if: true) {
                _stop()
                try await _start(config: config)
            }
        } catch {
            Logger.adapter.error("Failed to restart the connection: \(error, privacy: .public)")
        }
    }

    /// Records when the device went to sleep.
    func sleep() {
        guard case .running = state else { return }
        didSleepOn = date.now
    }

    /// Sends a `.networkSwitch` event to ProTUN if the device was asleep for longer than `transportExpiryThreshold`.
    /// ProTUN has a monotonic clock which doesn't advance during sleeps, so we need to poke it if we've been asleep for
    /// any amount of time that's likely to go past the default keepalive interval.
    func wake() {
        guard case .running = state, let lastSleepTime = didSleepOn else { return }
        didSleepOn = nil
        if date.now.timeIntervalSince(lastSleepTime) >= Self.transportExpiryThreshold {
            connection?.onConnectivityChange(event: .networkSwitch)
        }
    }
}

// MARK: - Network setup

extension ProTUNAdapter {
    func setNetworkSettings(excludingRoutes excludedRoutes: [String], dnsServers: [String]) async throws {
        Logger.adapter.debug("Generating settings {excludedRoutes: \(excludedRoutes, privacy: .public), dnsServers: \(dnsServers)}")
        let networkSettings = SettingsGenerator.settings(excludingRoutes: excludedRoutes, dnsServers: dnsServers)
        Logger.adapter.info("Settings tunnel network settings...")
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

// MARK: - Tunnel bringup + configuration

extension ProTUNAdapter {
    func handleForkSelector(_ selector: String, cookieName: String, cookieValue: String) {
        Logger.localAgent.info("Received fork selector from app")
        let forkSelectorInfo = ForkSelectorInfo(
            selector: selector,
            cookies: .init(items: [.init(name: cookieName, value: cookieValue)])
        )
        connection?.provideApiForkSelector(forkSelectorInfo: forkSelectorInfo)
    }

    func handlePeersUpdate(_ peers: [PeerInfo]) throws(Error) {
        guard let connection else {
            Logger.adapter.error("Cannot update peers: ProTUN connection is unavailable")
            throw .noConnection
        }
        connection.updatePeers(peers: peers)
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

    /// Single entry point for updating LocalAgentSettings.
    func applyLocalAgentSettings(_ settings: LocalAgentSettings) throws(Error) {
        guard let connection else {
            Logger.adapter.error("Cannot update Local Agent settings: ProTUN connection is unavailable")
            throw .noConnection
        }
        connection.updateLocalAgentSettings(settings: settings)
    }

    func requestLocalAgentStats() {
        connection?.requestLocalAgentStats()
    }

    func applyProviderConfigurationUpdate(
        _ update: ConnectionUpdate
    ) async throws(ConfigurationUpdateError) -> NETunnelProviderProtocol.ConnectionUpdateResult {
        // Read before touching the configuration (only works if connected).
        let currentPeer = await currentPeer

        guard let configuration = packetTunnelProvider?.protocolConfiguration as? NETunnelProviderProtocol
        else {
            throw .badConfiguration
        }

        do {
            try configuration.apply(update: update)
            #if os(macOS)
                // The saved configuration determines the packet filter policy.
                refreshPacketFilterPolicy()
            #endif
            return try configuration.updates(for: update, currentPeer: currentPeer)
        } catch {
            Logger.adapter.error(
                "Encountered encoding error when applying config update: \(error, privacy: .public)"
            )
            throw .badEncoding
        }
    }

    func enqueueConfigurationUpdate(_ update: ConnectionUpdate) async {
        await configurationStore.apply(update, adapter: self)
    }

    func reasserting<T, E: Swift.Error>(
        if required: Bool,
        _ closure: () async throws(E) -> sending T
    ) async throws(E) -> sending T {
        if required {
            packetTunnelProvider?.reasserting = true
            defer { packetTunnelProvider?.reasserting = false }
            return try await closure()
        } else {
            return try await closure()
        }
    }
}

// MARK: - Local Agent

private extension ProTUNAdapter {
    func startLocalAgentRunLoop() {
        localAgentTask = Task {
            let coordinator = LocalAgentCoordinator(adapter: self)

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await coordinator.start()
                }
                group.addTask {
                    let debouncedStream = coordinator.events.subscribe()._throttle(for: .milliseconds(250))
                    for await event in debouncedStream {
                        await self.handleLocalAgentCoordinatorEvent(event)
                    }
                }
            }
        }
    }

    func handleLocalAgentCoordinatorEvent(_ event: LocalAgentCoordinator.Event) {
        switch event {
        case .forkSelectorRequest:
            Logger.localAgent.info("Sending forkSelectorRequest tunnel command")
            extensionIPCServer.sendCommand(.forkSelectorRequest)
        }
    }
}

// MARK: - Device first unlock

extension ProTUNAdapter {
    /// Watches for the device's first unlock, restarting the tunnel if necessary.
    func listenForFirstUnlock() {
        firstUnlockTask?.cancel()

        let firstUnlock = IPCNotifications.ticks(.deviceFirstUnlocked)
        firstUnlockTask = Task {
            for await _ in firstUnlock {
                Logger.adapter.info("Device unlocked; checking connection for restart")
                handleFirstUnlock()
            }
        }
    }

    func handleFirstUnlock() {
        startQueue.addOperation { [weak self] in
            await self?.restartIfNotConnected()
        }
    }
}

// MARK: - Network Path updates

extension ProTUNAdapter {
    func listenToPathUpdates() {
        pathUpdatesTask?.cancel()

        pathUpdatesTask = Task {
            @Dependency(\.pathMonitor) var pathMonitorDependency
            let pathMonitor = pathMonitorDependency

            let stream = pathMonitor.subscribe()
            pathMonitor.start()

            await withTaskCancellationHandler {
                for await newPath in stream {
                    handleNetworkPathUpdate(old: networkPath, new: newPath)
                    networkPath = newPath
                }
            } onCancel: {
                pathMonitor.stop()
            }
        }
    }

    private func handleNetworkPathUpdate(old: NetworkPath, new: NetworkPath) {
        guard let event = NetworkPath.eventFromUpdates(old: old, new: new) else {
            Logger.adapter.debug("Ignoring connectivity event: \(new, privacy: .public)")
            return
        }
        Logger.adapter.info("Network path update: \(new, privacy: .public) (now \(event))")
        connection?.onConnectivityChange(event: event)
    }
}

// MARK: - Packet Capture

extension ProTUNAdapter {
    /// The capture to hand ProTUN with the initial connection, or nil when `config` declares none.
    private func configuredPacketCapture(for config: Configuration) -> PcapFileInfo? {
        guard let url = config.pcapCaptureFileURL else { return nil }

        @Dependency(\.fileManagerClient) var fileManagerClient
        let declaredFileSize: Int
        do {
            declaredFileSize = try fileManagerClient.fileSize(at: url)
        } catch {
            // A file we cannot read is one ProTUN creates on open, same as an empty one.
            Logger.adapter.info("Could not read the declared capture file: \(error, privacy: .public)")
            declaredFileSize = 0
        }

        guard declaredFileSize == 0 else {
            // The file already holds a finished capture, and opening it again would erase it. The app shows it as an
            // ended session, and the user's next capture start replaces it. This also handles the case where an
            // extension configured to start pcap on launch that crashes or otherwise exits will not re-start packet
            // capture on every launch.
            Logger.adapter.info("Declared capture file already holds packets, not starting over it")
            return nil
        }

        return PcapFileInfo(url: url, maxBytes: DomainConstants.LogFiles.pcapMaxFileSize)
    }

    /// Asks ProTUN to capture into `fileURL` on the running connection.
    func startPacketCapture(into fileURL: URL) {
        guard let connection else {
            Logger.adapter.info("No connection to capture from yet, leaving the request for the next start")
            return
        }

        extensionIPCServer.publishPacketCapture(.starting)
        connection.startPacketCapture(
            pcapFile: .init(url: fileURL, maxBytes: DomainConstants.LogFiles.pcapMaxFileSize)
        )
    }

    /// Reports the capture, and starts its time allowance, once the tunnel is connected. Works in both the tunnel start
    /// and active tunnel scenarios.
    func reportPacketCaptureWhenConnected() {
        cancelPacketCaptureDurationLimit()
        pcapDurationTask = Task {
            do {
                try await stateDelegate.whenState(\.isConnected, timeout: .never)
            } catch {
                // Tunnel was torn down or pcap was cancelled before connecting.
                return
            }
            Logger.adapter.info("Reporting the running packet capture")
            extensionIPCServer.publishPacketCapture(.recording(since: date.now))
            await stopCaptureAfterAllowedDuration()
        }
    }

    /// Asks ProTUN to stop capturing.
    func stopPacketCapture() {
        cancelPacketCaptureDurationLimit()
        connection?.stopPacketCapture()
    }

    private func stopCaptureAfterAllowedDuration() async {
        @Dependency(\.continuousClock) var clock
        try? await clock.sleep(for: .minutes(DomainConstants.LogFiles.pcapMaxDurationInMinutes))
        guard !Task.isCancelled else { return }
        Logger.adapter.info("Packet capture time limit reached, asking ProTUN to stop")
        stopPacketCapture()
    }

    private func cancelPacketCaptureDurationLimit() {
        pcapDurationTask?.cancel()
        pcapDurationTask = nil
    }

    struct Configuration {
        let userID: String
        let proTUN: ProTUNConfiguration
        var pcapCaptureFileURL: URL?

        static func legacy(proTUN: ProTUNConfiguration) -> Self {
            self.init(userID: NETunnelProviderProtocol.legacyMigrationUserID, proTUN: proTUN)
        }

        /// Whether `proTUN` was recovered from the pre-ProTUN WireGuard Go keychain entry rather than built from a
        /// connection request. In this case the session state alongside it needs migrating too. (See  ``LegacyKeychainMigration``).
        /// The app stores the same userID when it saves the migrated configuration it derived from that keychain
        /// entry; the same session is used until the user initiates their first connection with the app.
        var isLegacyFallback: Bool {
            userID == NETunnelProviderProtocol.legacyMigrationUserID
        }
    }
}

private extension PcapFileInfo {
    init(url: URL, maxBytes: Int) {
        self.init(file: .path(path: url.absolutePath, mode: .overwrite), maxBytes: UInt64(maxBytes))
    }
}

// MARK: - Helpers

extension NetworkPath {
    static func eventFromUpdates(old: NetworkPath, new: NetworkPath) -> ConnectivityEvent? {
        switch (old.isUsable, new.isUsable) {
        case (false, true): .up
        case (true, false): .down
        // avoid flapping connectivity events if the status hasn't meaningfully changed
        case (false, false): nil
        case (true, true): old == new ? nil : .networkSwitch
        }
    }
}

extension ProTUNAdapter {
    func initialConnectionConfig(
        proTUNConfig: ProTUNConfiguration,
        networkAvailable: Bool,
        localAgentSettings: LocalAgentSettings,
        pcapFile: protun.PcapFileInfo?
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
            pcapFile: pcapFile,
            connectionMode: .localAgent(
                userAgent: appInfo.userAgent,
                appVersion: appInfo.appVersion,
                settings: localAgentSettings,
                muonEnv: .prod,
                certificateDuration: .minutes(count: 10)
            ),
            sniStrategy: .random
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

    /// Whether ProTUN reports an established peer connection.
    var isConnected: Bool {
        if case .connected = connectionState {
            true
        } else {
            false
        }
    }
}

private extension IPCNotifications.Notification {
    /// Posted by keybagd when the user first unlocks the device after boot, opening sealed keychain items.
    static let deviceFirstUnlocked = Self(name: "com.apple.mobile.keybagd.first_unlock")
}
