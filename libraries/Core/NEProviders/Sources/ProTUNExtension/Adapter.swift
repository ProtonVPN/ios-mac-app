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

    /// Serializes every write to the provider configuration.
    private let configurationStore = ConfigurationStore()

    private let signposter = OSSignposter(logger: .adapter)

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

    func start(config: Configuration) async throws {
        // Measures the whole start sequence
        let signpostID = signposter.makeSignpostID()
        let startState = signposter.beginInterval("Start Tunnel", id: signpostID)
        defer { signposter.endInterval("Start Tunnel", startState) }

        Logger.adapter.info("Starting Adapter")
        @Dependency(\.extensionIPCServer) var extensionIPCServer
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
            @Dependency(\.extensionIPCServer) var extensionIPCServer
            extensionIPCServer.sendCommand(.forkSelectorRequest)
        }
    }

    func stop(with reason: NEProviderStopReason) {
        Logger.adapter.info("Stopping with reason: \(reason)")

        connection?.disconnect()

        pathUpdatesTask?.cancel()
        pathUpdatesTask = nil
        localAgentTask?.cancel()
        localAgentTask = nil

        // Clear the shared memory regions just before stopping.
        @Dependency(\.extensionIPCServer) var extensionIPCServer
        extensionIPCServer.zeroAll()
    }
}

extension ProTUNAdapter {
    func handleForkSelector(_ selector: String, cookieName: String, cookieValue: String) {
        Logger.localAgent.info("Received fork selector from app")
        let forkSelectorInfo = ForkSelectorInfo(
            selector: selector,
            cookies: .init(cookies: [.init(name: cookieName, value: cookieValue)])
        )
        connection?.provideApiForkSelector(forkSelectorInfo: forkSelectorInfo)
    }

    /// Single entry point for updating LocalAgentSettings.
    func applyLocalAgentSettings(_ settings: LocalAgentSettings) {
        connection?.updateLocalAgentSettings(settings: settings)
    }

    func enqueueConfigurationUpdate(_ update: ConnectionUpdate) async {
        await configurationStore.apply(update, adapter: self)
    }

    /// Enqueue a write of the server-applied Local Agent settings ProTUN reported. Serialized with user-initiated
    /// configuration updates so the two can't race on the provider configuration.
    func enqueueEffectiveLocalAgentSettings(_ settings: LocalAgentSettings) async {
        await configurationStore.persistEffective(settings, adapter: self)
    }

    func whileReasserting<T>(_ closure: () async throws -> T) async rethrows -> T {
        packetTunnelProvider?.reasserting = true
        defer { packetTunnelProvider?.reasserting = false }
        return try await closure()
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

    struct Configuration {
        let userID: String
        let proTUN: ProTUNConfiguration
    }
}

// MARK: - Helpers

extension ProTUNAdapter {
    func initialConnectionConfig(
        proTUNConfig: ProTUNConfiguration,
        networkAvailable: Bool,
        localAgentSettings: LocalAgentSettings
    ) throws(ProTUNAdapter.Error) -> InitialConnectionConfig {
        let peers = try proTUNConfig.peers.map { peer throws(ProTUNAdapter.Error) in
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

extension LocalAgentSettings {
    init(_ config: ProTUNConfiguration) {
        self.init(
            splitTcp: config.vpnAccelerator,
            netshieldLevel: config.netShieldLevel.flatMap { NetShieldType(rawValue: $0)?.toRustNetShieldLevel },
            softJail: config.softJail,
            portForwarding: config.portForwarding,
            randomNat: config.randomNat,
            circumventionRouting: config.circumventionRouting
        )
    }

    /// Overrides LocalAgent settings according to an update, leaving the rest unchanged. Used to build the
    /// settings forwarded to ProTUN from a partial update without persisting them to the configuration.
    mutating func apply(_ update: ConnectionUpdate) {
        if let netShield = update.netShield { netshieldLevel = netShield.toRustNetShieldLevel }
        if let vpnAccelerator = update.vpnAccelerator { splitTcp = vpnAccelerator }
        if let moderateNAT = update.moderateNAT { randomNat = moderateNAT.flag }
        if let portForwarding = update.portForwarding { self.portForwarding = portForwarding }
    }
}

extension ProTUNConfiguration {
    func with(
        peers: [Peer]? = nil,
        netShieldLevel: Int? = nil,
        vpnAccelerator: Bool? = nil,
        portForwarding: Bool? = nil,
        randomNat: Bool? = nil
    ) -> ProTUNConfiguration {
        ProTUNConfiguration(
            // `ProTUNConfiguration.init` takes a non-optional transport, so a configuration decoded without one (the
            // only way `preferredTransport` is nil) is normalised to `.udp`. In practice it is always written.
            preferredTransport: preferredTransport ?? .udp,
            peers: peers ?? self.peers,
            dnsServers: dnsServers,
            netShieldLevel: netShieldLevel ?? self.netShieldLevel,
            vpnAccelerator: vpnAccelerator ?? self.vpnAccelerator,
            portForwarding: portForwarding ?? self.portForwarding,
            randomNat: randomNat ?? self.randomNat,
            softJail: softJail,
            circumventionRouting: circumventionRouting
        )
    }

    /// Merges the ``LocalAgentSettings`` reported by ProTUN with the existing provider configuration.
    func merging(effectiveSettings settings: LocalAgentSettings) -> ProTUNConfiguration {
        with(
            netShieldLevel: settings.netshieldLevel.map(\.netShieldType.rawValue),
            vpnAccelerator: settings.splitTcp,
            portForwarding: settings.portForwarding,
            randomNat: settings.randomNat
        )
    }

    /// Whether the applied server settings differ from what this configuration requested for any
    /// user-facing Local Agent setting, and therefore need persisting so the app can observe the change.
    func localAgentSettingsDiffer(from effective: LocalAgentSettings) -> Bool {
        func differs<Value: Equatable>(_ requested: Value?, _ applied: Value?) -> Bool {
            guard let requested, let applied else { return false }
            return requested != applied
        }
        return differs(netShieldLevel, effective.netshieldLevel.map(\.netShieldType.rawValue))
            || differs(vpnAccelerator, effective.splitTcp)
            || differs(portForwarding, effective.portForwarding)
            || differs(randomNat, effective.randomNat)
    }
}

extension LocalAgentSettings {
    var agentTunnelFeatures: AgentTunnelFeatures {
        AgentTunnelFeatures(
            netshield: netshieldLevel?.netShieldType ?? .off,
            vpnAccelerator: splitTcp ?? false,
            natType: NATType(flag: randomNat ?? false),
            portForwarding: portForwarding
        )
    }
}

private extension NetshieldLevel {
    var netShieldType: NetShieldType {
        switch self {
        case .none: .off
        case .malwareFilter: .level1
        case .adsAndMalwareFilter: .level2
        case .adultAndAdsAndMalwareFilter: .level3
        @unknown default: .off
        }
    }
}

private extension NetShieldType {
    var toRustNetShieldLevel: NetshieldLevel {
        switch self {
        case .off:
            .none
        case .level1:
            .malwareFilter
        case .level2:
            .adsAndMalwareFilter
        case .level3:
            .adultAndAdsAndMalwareFilter
        }
    }
}
