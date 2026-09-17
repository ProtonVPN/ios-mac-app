//
//  Created on 29/05/2024.
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

import CasePaths
import Combine
import ConnectionShared
import CoreConnection
import Dependencies
import Domain
import ExtensionIPC
import ExtensionSync
import Foundation
import IPCDefinitions
import NetworkExtension
import os
import SharedErgonomics
import Sharing
import VPNAppCore
import VPNCoreCommon
import VPNCoreTypes

/// macOS-only XPC bridge that keeps the extension's `IOSurface` attached to the raw channels.
struct TunnelDataXPC: Sendable {
    var resume: @Sendable () -> Void = {}
    var cancel: @Sendable () -> Void = {}
}

extension TunnelDataXPC: DependencyKey {
    static let liveValue: TunnelDataXPC = {
        #if os(macOS)
            // Mirrors the `NEMachServiceName` entry in the System Extension's Info.plist.
            let serviceName = "\(DomainConstants.appIdentifierPrefix)group.ch.protonvpn.mac.WireGuard-Extension"
            let client = TunnelDataXPCClient(machServiceName: serviceName)
            return TunnelDataXPC(resume: { client.resume() }, cancel: { client.cancel() })
        #else
            return TunnelDataXPC()
        #endif
    }()

    static let testValue = TunnelDataXPC()
}

extension DependencyValues {
    var tunnelDataXPC: TunnelDataXPC {
        get { self[TunnelDataXPC.self] }
        set { self[TunnelDataXPC.self] = newValue }
    }
}

protocol TunnelManager {
    func startTunnel(with intent: ServerConnectionIntent) async throws
    #if !os(tvOS)
        func startZeroPeerTunnel() async throws
    #endif
    func stopTunnel() async throws

    func sendProTUN(request: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response

    func cleanup() async throws

    var status: TunnelState { get async throws }
    var statusStream: AsyncStream<Result<TunnelState, ExtensionError>> { get }

    var forkRequestsStream: AsyncStream<Void> { get }
}

@CasePathable
public enum TunnelState: Equatable, Sendable {
    case unknown // Initial state — not yet read from the system
    case invalid // VPN configuration not yet approved by the user
    case disconnected(TunnelConnectionError?)
    case connecting(TunnelConfiguration, tunnelActive: Bool) // `tunnelActive` indicates whether the interface is up
    case connectingToLocalAgent(
        TunnelConfiguration,
        tunnelActive: Bool,
        waitReason: IPCConnectionAgentWaitReason,
        jail: IPCConnectionAgentJailReason
    )
    case connected(TunnelConfiguration, DynamicConnectionData)
    case reasserting(TunnelConfiguration) // Briefly re-establishing an existing connection
    case disconnecting(TunnelConfiguration)
    case killSwitchActive(TunnelConfiguration)
}

/// Data relating to the connection that is strongly tied to the tunnel's configuration.
/// This data can only change when the configuration is written to, and reloaded
public struct TunnelConfiguration: Equatable, Sendable, Codable {
    /// The spec represents the user's original intent when initiating this connection
    /// The tunnel configuration must be updated accordingly whenever a change is applied
    ///
    /// Connection layer overrides it with a `fallbackSpec` for IKEv2
    public let connectionSpec: ConnectionSpec
    public let tunnelProtocol: TunnelProtocol
    public let peerIDs: [String]
    /// Whether the saved configuration carries the kill switch flag (`includeAllNetworks`): the tunnel
    /// blocks traffic when it drops or runs with zero peers. Because this is read off the configuration,
    /// it reports what the tunnel was actually given, while the settings hold what the user requested
    /// for the next connection.
    public let killSwitch: Bool

    public init(connectionSpec: ConnectionSpec, tunnelProtocol: TunnelProtocol, peerIDs: [String], killSwitch: Bool) {
        self.connectionSpec = connectionSpec
        self.tunnelProtocol = tunnelProtocol
        self.peerIDs = peerIDs
        self.killSwitch = killSwitch
    }
}

/// Runtime data that becomes available once the tunnel is connected.
public struct DynamicConnectionData: Equatable, Sendable {
    /// The ID of the peer we are connected to, or `nil` when the tunnel is up but the peer isn't yet confirmed
    public let currentPeerId: String?

    /// The date at which the tunnel first entered the `connected` state.
    public let connectionDate: Date

    /// Protocol specific data
    public let protocolConnectionData: ProtocolConnectionData

    public init(currentPeerId: String?, connectionDate: Date, protocolConnectionData: ProtocolConnectionData) {
        self.currentPeerId = currentPeerId
        self.connectionDate = connectionDate
        self.protocolConnectionData = protocolConnectionData
    }
}

/// Extra information reported by the tunnel.
/// Type of data depends on the connection protocol.
@CasePathable
public enum ProtocolConnectionData: Equatable, Sendable, Codable {
    case ike
    case proTUN(ProTUNConnectionData)

    /// The ProTUN payload, or `nil` when the connection runs over IKEv2.
    public var proTUNData: ProTUNConnectionData? {
        guard case let .proTUN(data) = self else { return nil }
        return data
    }

    public struct ProTUNConnectionData: Equatable, Sendable, Codable {
        public let transport: Domain.WireGuardTransport
        /// The exit addresses the local agent reports, per family. A server can answer with either,
        /// or both.
        public let serverExitV4: String?
        public let serverExitV6: String?
        public let userISP: String?
        public let userIP: String?

        public init(
            transport: Domain.WireGuardTransport,
            serverExitV4: String? = nil,
            serverExitV6: String? = nil,
            userISP: String? = nil,
            userIP: String? = nil
        ) {
            self.transport = transport
            self.serverExitV4 = serverExitV4
            self.serverExitV6 = serverExitV6
            self.userISP = userISP
            self.userIP = userIP
        }
    }
}

enum TunnelManagerKey: DependencyKey {
    #if DEBUG && targetEnvironment(simulator)
        static let liveValue: TunnelManager = {
            log.debug("Simulator: using mocked VPN internals", category: .connection)
            let mockSession = VPNSessionMock(status: .disconnected)
            mockSession.messageHandler = MessageHandler.full
            return MockTunnelManager(connection: mockSession)
        }()
    #else
        static let liveValue: TunnelManager = PacketTunnelManager()
    #endif
}

final class PacketTunnelManager: TunnelManager {
    /// Where the user last asked to connect in this process.
    private let lastConnectionSpec: OSAllocatedUnfairLock<ConnectionSpec?> = .init(initialState: nil)

    @Dependency(\.vpnManagerRepository) private var managerRepository

    /// The NEPacketTunnelProvider connection state, as reported by the ProTUN framework. Sent over a shared memory
    /// channel directly from the extension.
    /// - Note: If the selected protocol is IKEv2, this will read as `.disconnected`.
    @SharedReader(.extensionState) private var extensionState = ExtensionStateSnapshot(
        state: .disconnected(reason: .unset),
        requestId: nil
    )

    /// The extension's most-recent reported error (carrying the request id it pertains to), sent over the error channel.
    @SharedReader(.extensionError) private var extensionError: ExtensionError? = nil

    /// Where the user last asked to connect in this process, else the most recent connection on record.
    private func recoveredConnectionSpec() -> ConnectionSpec? {
        @SharedReader(.recentConnections) var recentConnections
        return lastConnectionSpec.withLock { $0 }
            ?? recentConnections?.elements.first?.connection
    }

    /// Fork requests posted by the extension, a new stream for each observer
    /// we should use shared() streams in the future for this
    var forkRequestsStream: AsyncStream<Void> {
        @Dependency(\.extensionIPC) var extensionIPC
        let commands = extensionIPC.observeCommands()

        return AsyncStream { continuation in
            let task = Task {
                for await command in commands {
                    switch command {
                    case .forkSelectorRequest:
                        continuation.yield()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func startTunnel(with intent: ServerConnectionIntent) async throws {
        log.debug(
            "Starting tunnel with configuration: \(intent.protocolConfiguration)",
            category: .connection,
            metadata: ["tunnelFeatures": "\(intent.tunnelFeatures)"]
        )

        // Keep the spec here as well as in the saved configuration to account for a race window during connection, when
        // the extension can check in before the NE framework has persisted the new provider configuration.
        lastConnectionSpec.withLock { $0 = intent.spec }

        // Prepare the configuration - this may prompt the user for VPN permissions
        let manager = try await managerRepository.prepareManager(intent.tunnelProtocol, .connection(intent))

        log.debug("Starting tunnel with bundle identifier: \(optional: manager.providerBundleIdentifier)", category: .connection)
        try Task.checkCancellation()

        // NetworkExtension silently drops a start issued while the previous connection is still tearing down (the
        // daemon logs "Skip a start command ... session in state disconnecting"). Wait the teardown out so the start
        // lands. Bounded with a timeout, after which the start is attempted anyway.
        if manager.session.status == .disconnecting {
            log.debug("Waiting out tunnel teardown before starting", category: .connection)
            let statusChanges = NotificationCenter.default.notifications(named: .NEVPNStatusDidChange)
            do {
                try await withTimeout(of: .seconds(10)) {
                    guard manager.session.status == .disconnecting else { return }
                    for await _ in statusChanges where manager.session.status != .disconnecting {
                        break
                    }
                }
            } catch {
                SentryHelper.shared?
                    .log(message: "Could not wait for disconnect: \(error), connection is \(manager.session.status)")
                log.error("Could not wait for disconnect: \(error), connection is \(manager.session.status)")
            }

            try Task.checkCancellation()
        }

        try manager.session.startTunnel()
    }

    #if !os(tvOS)
        /// Starts a zero-peer ProTUN tunnel from a disconnected state to enforce Advanced kill switch blocking.
        /// May prompt for VPN permission the first time. The tunnel comes up intercepting all traffic
        /// with no peer, so it blocks until a real connection replaces the configuration
        func startZeroPeerTunnel() async throws {
            let manager = try await managerRepository.prepareManager(.wireGuard, .zeroPeerColdStart)
            try Task.checkCancellation()
            try manager.session.startTunnel()
        }
    #endif

    func stopTunnel() async throws {
        let managers = try await managerRepository.managers()
        let activeProtocols = managers
            .filter { $0.value.session.status != .disconnected && $0.value.session.status != .invalid }
            .map(\.key)

        guard !activeProtocols.isEmpty else {
            throw TunnelManagerError.missingConfiguration
        }

        // Disable on-demand before stopping, to prevent auto-reconnect.
        // Stop all active managers to avoid ending up with concurrent protocol sessions.
        for proto in activeProtocols {
            let manager = try await managerRepository.prepareManager(proto, .disconnection)
            log.debug("Stopping tunnel for protocol \(proto)")
            manager.session.stopTunnel()
        }
    }

    func sendProTUN(request: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response {
        let manager: TunnelProviderManager
        do {
            manager = switch request.payload {
            case let .updateConfiguration(update):
                try await managerRepository.prepareManager(.wireGuard, .update(update))
            case let .pcapRequest(.start(fileURL)):
                try await managerRepository.prepareManager(.wireGuard, .packetCapture(fileURL: fileURL))
            case .pcapRequest(.stop):
                try await managerRepository.prepareManager(.wireGuard, .packetCapture(fileURL: nil))
            default:
                try await managerRepository.manager(for: .wireGuard)
            }
        } catch let error as ProviderMessageError {
            throw error
        } catch is CancellationError {
            throw .cancelled
        } catch {
            log.debug("Failed to prepare the manager for a ProTUN request", category: .ipc, metadata: ["error": "\(error)"])
            throw .sendingError(.managerUnavailable(error))
        }

        do {
            return try await manager.session.sendProTUNRequest(request)
        } catch let error as ProviderMessageError {
            throw error
        } catch is CancellationError {
            throw .cancelled
        } catch {
            log.debug("Failed to send ProTUN request", category: .ipc, metadata: ["error": "\(error)"])
            throw .sendingError(.internalSendFailed(error))
        }
    }

    var status: TunnelState {
        get async throws {
            // If we can't find a manager that doesn't report an "active" state, report disconnected. `activeManager`
            // ranks the different VPN configurations by figuring out which one is the "most connected," and then
            // returns it here. Useful for handling multiple VPN configurations at once.
            guard let (tunnelProtocol, manager) = try await activeManager() else {
                return .disconnected(nil)
            }

            let snapshot = extensionState

            // Error surfacing is the streaming path's job, so passing `nil` as the error guarantees a `.success` result
            return try resolve(
                tunnelProtocol: tunnelProtocol,
                session: manager.session,
                configuration: manager.protocolConfiguration,
                extensionState: snapshot.state,
                appliedRequestId: snapshot.requestId,
                isOnDemandEnabled: manager.isOnDemandEnabled,
                error: nil
            ).get()
        }
    }

    /// A simple accumulator type for all of the values reported by the different streams. We separate the NEVPNManager
    /// from the NETunnelProviderManager so that we can distinguish between which one represents the active connection.
    /// Stale entries are left in place so that the next update to the status stream from one of the two sources can use
    /// the other stream's latest value.
    private struct Accumulator {
        var tunnelProviderManager: (any TunnelProviderManager)?
        var extensionState: ExtensionState?
        var appliedRequestId: UUID?
        var error: ExtensionError?
        var lastEmitted: Result<TunnelState, ExtensionError>?
        var lastEmittedRequestId: UUID?

        #if os(macOS)
            var vpnManager: (any TunnelProviderManager)?
        #endif
    }

    /// Updates a manager in the Accumulator according to its class. This function only really needs to exist at the
    /// moment because of macOS + IKEv2, once that goes away we can probably get rid of it.
    private func track(_ manager: NEVPNManager, into tracked: inout Accumulator) {
        if let tunnelProvider = manager as? NETunnelProviderManager {
            tracked.tunnelProviderManager = tunnelProvider
        } else {
            #if os(macOS)
                if manager is NETransparentProxyManager {
                    return
                }
                tracked.vpnManager = manager
            #endif
        }
    }

    /// Ranks the tracked managers by activity and resolves the most-active one. This means that if we receive an update
    /// to the `ExtensionState` and get called here, and the "activity priority" (i.e. level of connectivity) of IKEv2
    /// is greater, we will still report the connection state for IKEv2 instead, or at least until ProTUN is "more
    /// connected" than the IKEv2 layer.
    private func resolve(_ tracked: Accumulator) -> Result<TunnelState, ExtensionError> {
        #if os(macOS)
            let managers = [
                (TunnelProtocol.wireGuard, tracked.tunnelProviderManager),
                (TunnelProtocol.ike, tracked.vpnManager),
            ]

            guard let (tunnelProtocol, manager) = managers.max(by: {
                $0.1?.session.status.activityPriority ?? 0 < $1.1?.session.status.activityPriority ?? 0
            }), let manager else { return .success(.disconnected(nil)) }
        #else
            guard let manager = tracked.tunnelProviderManager else { return .success(.disconnected(nil)) }
            let tunnelProtocol = TunnelProtocol.wireGuard
        #endif

        return resolve(
            tunnelProtocol: tunnelProtocol,
            session: manager.session,
            configuration: manager.protocolConfiguration,
            extensionState: tracked.extensionState,
            appliedRequestId: tracked.appliedRequestId,
            isOnDemandEnabled: manager.isOnDemandEnabled,
            error: tracked.error
        )
    }

    /// Dispatches to the protocol-specific tunnel resolver. This is the single entry point for both `status` and
    /// `statusStream`, this is so that the stream can pass the published values directly rather than re-reading them
    /// and the one-shot `status` getter can re-use all of the same logic.
    private func resolve(
        tunnelProtocol: TunnelProtocol,
        session: VPNSession,
        configuration: NEVPNProtocol?,
        extensionState: ExtensionState?,
        appliedRequestId: UUID?,
        isOnDemandEnabled: Bool,
        error: ExtensionError?
    ) -> Result<TunnelState, ExtensionError> {
        switch tunnelProtocol {
        case .ike:
            #if os(macOS)
                return resolveIKE(session: session, configuration: configuration)
            #else
                assertionFailure("IKE is not supported on this platform")
                return .success(.disconnected(nil))
            #endif
        case .wireGuard:
            return resolveProTUN(
                session: session,
                configuration: configuration as? NETunnelProviderProtocol,
                extensionState: extensionState,
                appliedRequestId: appliedRequestId,
                isOnDemandEnabled: isOnDemandEnabled,
                error: error
            )
        }
    }

    #if os(macOS)
        /// IKEv2 has no extension channel (and so no error channel), so NetworkExtension's reported status is authoritative.
        private func resolveIKE(session: VPNSession, configuration: NEVPNProtocol?) -> Result<TunnelState, ExtensionError> {
            guard let configuration else { return .success(.disconnected(nil)) }

            let peerIDs: [String]
            let connectionSpec: ConnectionSpec

            do {
                peerIDs = try configuration.peerIDs
            } catch {
                log.warning("Could not recover IKE peer IDs: \(error)", category: .connection)
                peerIDs = []
            }

            connectionSpec = recoveredConnectionSpec() ?? ConnectionSpec()

            let config = TunnelConfiguration(
                connectionSpec: connectionSpec,
                tunnelProtocol: .ike,
                peerIDs: peerIDs,
                killSwitch: configuration.includeAllNetworks
            )

            switch session.status {
            case .invalid:
                return .success(.invalid)
            case .disconnected:
                return .success(.disconnected(nil))
            case .connecting, .reasserting:
                // IKE has no in-place peer change, so only NetworkExtension's own reassertion keeps an interface
                // holding traffic while the connection is re-established.
                return .success(.connecting(config, tunnelActive: session.status == .reasserting))
            case .disconnecting:
                return .success(.disconnecting(config))
            case .connected:
                @Dependency(\.date) var date
                let serverID = (try? configuration.ikePeerID) ?? ""
                if serverID.isEmpty {
                    log.warning(
                        "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID",
                        category: .connection
                    )
                    SentryHelper.shared?.log(message: "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID")
                }

                return .success(.connected(
                    config,
                    .init(
                        currentPeerId: serverID,
                        connectionDate: session.connectedDate ?? date.now,
                        protocolConnectionData: .ike
                    )
                ))
            @unknown default:
                return .success(.disconnected(nil))
            }
        }
    #endif

    /// Resolves the tunnel state for ProTUN from both the `NEVPNStatus` that NetworkExtension reports and the extension
    /// state that ProTUN publishes over the tunnel-data channels.
    private func resolveProTUN(
        session: VPNSession,
        configuration: NETunnelProviderProtocol?,
        extensionState: ExtensionState?,
        appliedRequestId: UUID?,
        isOnDemandEnabled: Bool,
        error: ExtensionError?
    ) -> Result<TunnelState, ExtensionError> {
        guard let configuration else { return .success(.disconnected(nil)) }

        // NE preferences record intent (the app writes them before every request) and add a UUID to every configuration
        // update to allow the app to know what the extension is still awaiting on. Equal IDs mean nothing is pending.
        // If an error comes in and the IDs are different, then the error in question is directly relevant to the
        // configuration we just applied. Surface to the user if possible.
        let quiesced = appliedRequestId != nil && appliedRequestId == configuration.requestId
        if quiesced, let error {
            return .failure(error)
        }

        // The saved configuration records where the user asked to connect. It can be missing for a brief window when
        // connecting if the extension checks in with the app before the NE framework has persisted the configuration.
        // To account for this case we return what was previously recorded if it's missing or fails to decode.
        let connectionSpec: ConnectionSpec
        do {
            connectionSpec = try configuration.connectionSpec ?? recoveredConnectionSpec() ?? ConnectionSpec()
        } catch {
            log.error("The recorded connection spec failed to decode: \(error)", category: .connection)
            connectionSpec = recoveredConnectionSpec() ?? ConnectionSpec()
        }

        #if os(tvOS)
            let killSwitch = false
        #else
            let killSwitch = configuration.includeAllNetworks
        #endif
        let config = TunnelConfiguration(
            connectionSpec: connectionSpec,
            tunnelProtocol: .wireGuard,
            peerIDs: extensionState?.peerID.map { [$0] } ?? [],
            killSwitch: killSwitch
        )
        let decodedPeers: [String]?
        do {
            decodedPeers = try configuration.peerIDs
        } catch {
            log.error("Unable to decode peers \(error)", category: .connection)
            decodedPeers = nil
        }
        let intendedPeers = decodedPeers ?? []
        // A failed decode says nothing about intent, so only a decoded empty peer list means zero-peer blocking.
        let requestsZeroPeerKillSwitch = killSwitch && decodedPeers?.isEmpty == true

        // NetworkExtension reports a connected interface during peer handover, and only transitions from its own
        // connecting status when the interface is genuinely new. So while the extension works through its connecting
        // states, this says whether traffic is already held.
        let tunnelActive = [.connected, .reasserting].contains(session.status)

        // We need to suppress spurious `.connecting` events from the extension resulting from the configuration change
        // of disabling on-demand.
        let teardownEcho = session.status == .connecting && session.connectedDate != nil
        if !isOnDemandEnabled, teardownEcho {
            log.debug("Suppressing spurious `.connecting` event for on-demand disabled")
            return .success(.disconnecting(config))
        }

        // Defers mostly to the NE framework for the disconnected cases, and mostly to ProTUN for the connected cases.
        // A notable special case is ExtensionState.connected, where we check the tunnel sits on a peer the saved
        // configuration intends before reporting a connected state.
        switch (session.status, extensionState) {
        case (_, nil):
            return .success(.unknown)
        case (.invalid, _):
            // System has no usable configuration for this manager (never approved, or just removed (due to a session
            // change or user deleting the profile). Returning `.invalid` resolves to a disconnected connection state.
            return .success(.invalid)
        case (_, .disconnected):
            // With no peer, Rust reports `.disconnected` even when the tunnel interface is alive and blackholing
            // traffic. The saved configuration describes the zero-peer intent, the matching request id confirms
            // the extension applied it, and the session status tells whether the interface is actually up.
            let sessionIsUp = [.connected, .connecting, .reasserting].contains(session.status)
            if requestsZeroPeerKillSwitch {
                if sessionIsUp {
                    guard quiesced else {
                        return .success(.reasserting(config))
                    }
                    return .success(.killSwitchActive(config))
                }
                if session.status == .disconnecting {
                    return .success(.disconnecting(config))
                }
                return .success(.disconnected(nil))
            }
            // The saved configuration wants peers (a fresh connection starting, or connecting out from zero-peer), but
            // Rust still reports the peerless state. This covers the window before the extension applies the update and
            // the window right after, where the request id already matches but the connection attempt has not begun.
            // The tunnel interface is up, so hold the last state instead of reporting a disconnection that is not
            // happening.
            if sessionIsUp, !intendedPeers.isEmpty {
                return .success(.reasserting(config))
            }
            return .success(.disconnected(nil))
        case (.disconnected, _):
            return .success(.disconnected(nil))
        case (.disconnecting, _):
            return .success(.disconnecting(config))
        case let (_, .connected(peer)):
            // Checked ahead of the `.connecting` cases below: saving NE preferences in place for a config update
            // (e.g. custom DNS) can briefly flip the reported `NEVPNStatus` to `.connecting` on macOS even though
            // nothing is actually reconnecting. Trust the extension's own `.connected` state while the tunnel is on
            // an intended peer: a pending feature-only update never moves the peer, and a location change either
            // rewrites the intended peers (failing this check) or flips the extension to a connecting state the
            // moment it starts reasserting.
            guard intendedPeers.contains(peer.peerID) else {
                return .success(.reasserting(config))
            }
            if !quiesced {
                log.debug(
                    "Extension reports connected, but the in-flight config request hasn't been acknowledged yet",
                    category: .connection,
                    metadata: [
                        "appliedRequestId": "\(optional: appliedRequestId)",
                        "configRequestId": "\(optional: configuration.requestId)",
                    ]
                )
            }

            @Dependency(\.date) var date
            return .success(.connected(
                config,
                .init(
                    currentPeerId: peer.peerID,
                    connectionDate: session.connectedDate ?? date.now,
                    protocolConnectionData: .proTUN(.init(
                        transport: peer.transport,
                        serverExitV4: peer.serverExitV4,
                        serverExitV6: peer.serverExitV6,
                        userISP: peer.userISP,
                        userIP: peer.userIP
                    ))
                )
            ))
        case (.connecting, _), (_, .connecting):
            guard quiesced, let peerID = extensionState?.peerID, intendedPeers.contains(peerID) else {
                return .success(.reasserting(config))
            }
            return .success(.connecting(config, tunnelActive: tunnelActive))
        case let (_, .connectingToLocalAgent(_, waitReason, jail)):
            guard quiesced, let peerID = extensionState?.peerID, intendedPeers.contains(peerID) else {
                return .success(.reasserting(config))
            }
            return .success(.connectingToLocalAgent(
                config,
                tunnelActive: tunnelActive,
                waitReason: waitReason,
                jail: jail
            ))
        }
    }

    var statusStream: AsyncStream<Result<TunnelState, ExtensionError>> {
        log.debug("Creating TunnelState stream for tunnel observation", category: .connection)
        return AsyncStream { continuation in
            // Every source updates its value in `tracked`, re-resolves from the latest snapshot and emits only when the
            // resolved result changes.
            let tracked = OSAllocatedUnfairLock(uncheckedState: Accumulator())

            // Helper function for state resolution. Calls the closure with the accumulator, checks if the resolved
            // result has changed, and returns it (or `nil` if it's stayed the same).
            func resolved(after update: (inout Accumulator) -> Void) -> Result<TunnelState, ExtensionError>? {
                tracked.withLockUnchecked { state in
                    update(&state)
                    let resolved = resolve(state)
                    if case .success(.reasserting(_)) = resolved, state.lastEmitted != nil {
                        return nil
                    }
                    let squelched = resolved == state.lastEmitted && state.appliedRequestId == state.lastEmittedRequestId
                    guard !squelched else {
                        log.debug("Ignoring tunnel state update \(state); resolved to the last emitted state", category: .connection)
                        return nil
                    }
                    state.lastEmitted = resolved
                    state.lastEmittedRequestId = state.appliedRequestId
                    return resolved
                }
            }

            // Provide the initial value for the stream. The notification tasks wait for this to complete before
            // starting their event loops.
            let seedTask = Task {
                @Dependency(\.vpnManagerRepository) var managerRepository
                guard let managers = try? await managerRepository.managers() else { return }
                let snapshot = extensionState
                let error = self.extensionError

                if let state = resolved(after: { tracked in
                    tracked.tunnelProviderManager = managers[.wireGuard]
                    #if os(macOS)
                        tracked.vpnManager = managers[.ike]
                    #endif
                    tracked.extensionState = snapshot.state
                    // Prefer a pending error's request id, so an unacked error can still surface.
                    tracked.appliedRequestId = error?.id ?? snapshot.requestId
                    tracked.error = error
                }) {
                    continuation.yield(state)
                }
            }

            // Feeds `NEVPNStatusDidChange` notifications to the resolver.
            let statusTask = Task {
                _ = await seedTask.value
                for await notification in NotificationCenter.default.notifications(named: .NEVPNStatusDidChange) {
                    guard let manager = (notification.object as? NEVPNConnection)?.manager else {
                        let configName = if let tunnelProviderSession = notification.object as? NETunnelProviderSession {
                            tunnelProviderSession.manager.localizedDescription ?? "unknown config"
                        } else {
                            "unknown config"
                        }
                        log.info("Tunnel manager ignoring config update for \(configName).")
                        continue
                    }
                    let configRequestId = (manager.protocolConfiguration as? NETunnelProviderProtocol)?.requestId
                    log.debug(
                        "NEVPNStatusDidChange: \(manager.connection.status)",
                        category: .connection,
                        metadata: ["configRequestId": "\(optional: configRequestId)"]
                    )

                    guard let state = resolved(after: { track(manager, into: &$0) }) else { continue }

                    continuation.yield(state)
                }
            }

            // Feeds `ExtensionState` updates to the resolver. The app is the only process that moves anything the
            // resolver reads from NE preferences, and it reloads after its own saves, so the accumulator's manager
            // is already fresh here.
            let extensionStateTask = Task {
                _ = await seedTask.value
                for await extensionState in $extensionState.publisher.values {
                    guard let state = resolved(after: {
                        $0.extensionState = extensionState.state
                        $0.appliedRequestId = extensionState.requestId
                    }) else { continue }
                    continuation.yield(state)
                }
            }

            // Feeds error-channel updates to the resolver.
            let errorTask = Task {
                _ = await seedTask.value
                for await error in $extensionError.publisher.values {
                    guard let state = resolved(after: {
                        $0.error = error
                        if let requestId = error?.id {
                            $0.appliedRequestId = requestId
                        }
                    }) else { continue }
                    continuation.yield(state)
                }
            }

            continuation.onTermination = { _ in
                seedTask.cancel()
                statusTask.cancel()
                extensionStateTask.cancel()
                errorTask.cancel()
            }
        }
    }

    private func activeManager() async throws -> (TunnelProtocol, any TunnelProviderManager)? {
        let managers = try await managerRepository.managers()
        let activeManagers = managers.filter { _, manager in
            manager.session.status != .disconnected && manager.session.status != .invalid
        }
        guard !activeManagers.isEmpty else {
            return nil
        }
        return activeManagers.max {
            $0.value.session.status.activityPriority < $1.value.session.status.activityPriority
        }
    }

    func cleanup() async throws {
        try await managerRepository.removeAllManagers()
    }
}

enum TunnelManagerError: Error {
    case ipc(WireguardProviderRequest, Error?)
    case protunIPC(String)
    case malformedConfiguration
    case noManagerFound
    case missingConfiguration
    case statusResolutionFailed(Error)
}

extension TunnelManagerError: ProtonVPNError {
    static let errorDomain = "TunnelManagerErrorDomain"

    var charCode: FourCharCode {
        switch self {
        case .ipc: "TMIP"
        case .protunIPC: "TMPI"
        case .malformedConfiguration: "TMMC"
        case .noManagerFound: "TMNM"
        case .missingConfiguration: "TMMG"
        case .statusResolutionFailed: "TMSR"
        }
    }

    var underlyingError: Error? {
        switch self {
        case let .ipc(_, error): error
        case let .statusResolutionFailed(error): error
        case .protunIPC, .malformedConfiguration, .noManagerFound, .missingConfiguration: nil
        }
    }
}

extension DependencyValues {
    var tunnelManager: TunnelManager {
        get { self[TunnelManagerKey.self] }
        set { self[TunnelManagerKey.self] = newValue }
    }
}

extension ServerConnectionIntent {
    var tunnelProtocol: TunnelProtocol {
        switch protocolConfiguration {
        case .ike:
            #if os(macOS)
                return .ike
            #else
                assertionFailure("Unsupported backend on non-macOS platforms")
                return .wireGuard
            #endif
        case .wireGuard:
            return .wireGuard
        }
    }
}

private extension NEVPNProtocol {
    /// Extracts the server ID from an IKE configuration's username.
    ///
    /// The username is built by `WireguardConfigurator.ikeUsername(...)` as
    /// `<base>+<feature1>+...+ep:<serverID>`. The endpoint chunk is identified by the
    /// `ep:` token (`IkeUsernameComponent.endpointIDPrefix`)
    var ikePeerID: String {
        get throws {
            guard let username, !username.isEmpty else {
                throw TunnelManagerError.malformedConfiguration
            }
            let token = "\(IkeUsernameComponent.concatChar)\(IkeUsernameComponent.endpointIDPrefix)"
            guard let range = username.range(of: token) else {
                throw TunnelManagerError.malformedConfiguration
            }
            let afterToken = username[range.upperBound...]
            // The endpoint ID itself is sanitised to strip `+`, so anything up to the next
            // `+` (if any) is the encoded server ID. In practice `endpointID` is the last
            // component appended, so there is no further separator — the trim is defensive.
            if let endIndex = afterToken.firstIndex(of: IkeUsernameComponent.concatChar) {
                return String(afterToken[..<endIndex])
            }
            return String(afterToken)
        }
    }
}

private extension NEVPNStatus {
    /// Ranks tunnel statuses by "how active the tunnel is", with `.connected` highest. Used to
    /// pick the most-active manager when several `NETunnelProviderManager`s exist in parallel
    /// (e.g. during a protocol switch).
    var activityPriority: Int {
        switch self {
        case .connected: 4
        case .reasserting: 3
        case .connecting: 2
        case .disconnecting: 1
        case .invalid, .disconnected: 0
        @unknown default: 0
        }
    }
}

extension NEVPNProtocol {
    var peerIDs: [String] {
        get throws {
            guard self is NETunnelProviderProtocol else {
                assert(self is NEVPNProtocolIKEv2)
                // If we're not an NETunnelProviderProtocol, we are an IKE configuration.
                return try [ikePeerID]
            }

            let configuration: ProTUNConfiguration
            do {
                configuration = try ProTUNConfigurationCoder.decode(from: self)
            } catch .providerConfigurationMissing, .proTUNConfigurationMissing {
                // Migration from a previous WireGuard connection:
                // Attempt to recover the peer ID from the legacy keychain
                configuration = try ProTUNConfigurationCoder.legacyDecode(from: self)
            } catch {
                throw error
            }
            return configuration.peers.map(\.id)
        }
    }
}
