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
import Foundation
import IPCErgonomics
import LocalAgent
import LocalAgentIPC
import NetworkExtension
import os
import Sharing
import VPNAppCore
import VPNCoreCommon
import VPNCoreTypes

/// macOS-only XPC bridge that (re)attaches the extension's `IOSurface` to the raw channels.
struct TunnelDataXPC: Sendable {
    var attach: @Sendable () -> Void = {}
    var reattach: @Sendable () -> Void = {}
}

extension TunnelDataXPC: DependencyKey {
    static let liveValue: TunnelDataXPC = {
        #if os(macOS)
            // Mirrors the `NEMachServiceName` entry in the System Extension's Info.plist.
            let serviceName = "\(DomainConstants.appIdentifierPrefix)group.ch.protonvpn.mac.WireGuard-Extension"
            let client = TunnelDataXPCClient(machServiceName: serviceName)
            return TunnelDataXPC(attach: { client.attachRegion() }, reattach: { client.reattachRegion() })
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

enum TunnelMessageTarget {
    /// Send to whichever extension is currently active.
    case active
    /// Send to the extension managing the specified tunnel protocol.
    case specific(TunnelProtocol)
}

protocol TunnelManager {
    func startTunnel(with intent: ServerConnectionIntent) async throws
    func stopTunnel() async throws

    func sendProTUN(request: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response

    func cleanup() async throws

    var status: TunnelState { get async throws }
    var statusStream: AsyncStream<TunnelState> { get }

    var forkRequestsStream: AsyncStream<Void> { get }
}

@CasePathable
public enum TunnelState: Equatable, Sendable {
    case unknown // Initial state — not yet read from the system
    case invalid // VPN configuration not yet approved by the user
    case disconnected(TunnelConnectionError?)
    case connecting(TunnelConfiguration)
    case connected(TunnelConfiguration, DynamicConnectionData)
    case reasserting(TunnelConfiguration) // Briefly re-establishing an existing connection
    case disconnecting(TunnelConfiguration)
}

/// Data relating to the connection that is strongly tied to the tunnel's configuration.
/// This data can only change when the configuration is written to, and reloaded
public struct TunnelConfiguration: Equatable, Sendable {
    /// The spec represents the user's original intent when initiating this connection
    /// The tunnel configuration must be updated accordingly whenever a change is applied
    ///
    /// Connection layer overrides it with a `fallbackSpec` for IKEv2
    public let connectionSpec: ConnectionSpec
    public let tunnelProtocol: TunnelProtocol
    public let peerIDs: [String]

    public init(connectionSpec: ConnectionSpec, tunnelProtocol: TunnelProtocol, peerIDs: [String]) {
        self.connectionSpec = connectionSpec
        self.tunnelProtocol = tunnelProtocol
        self.peerIDs = peerIDs
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
public enum ProtocolConnectionData: Equatable, Sendable {
    case ike
    case proTUN(ProTUNConnectionData)

    var proTUNData: ProTUNConnectionData? {
        guard case let .proTUN(data) = self else { return nil }
        return data
    }

    public struct ProTUNConnectionData: Equatable, Sendable {
        public let transport: Domain.WireGuardTransport
        public let serverExitV4: String?
        public let userISP: String?
        public let userIP: String?

        public init(
            transport: Domain.WireGuardTransport,
            serverExitV4: String? = nil,
            userISP: String? = nil,
            userIP: String? = nil
        ) {
            self.transport = transport
            self.serverExitV4 = serverExitV4
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
    let forkRequestsStream: AsyncStream<Void>
    let lastConnectionSpec: OSAllocatedUnfairLock<ConnectionSpec?> = .init(initialState: nil)

    #if os(macOS)
        @Dependency(\.tunnelDataXPC) var tunnelDataXPC
    #endif

    /// The NEPacketTunnelProvider connection state, as reported by the ProTUN framework. Sent over a shared memory
    /// channel directly from the extension.
    /// - Note: If the selected protocol is IKEv2, this will read as `.disconnected`.
    @SharedReader(.extensionState) private var extensionState: ExtensionState = .disconnected(reason: .unset)

    private let forkRequestsContinuation: AsyncStream<Void>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.forkRequestsStream = stream
        self.forkRequestsContinuation = continuation

        @Dependency(\.extensionIPC) var extensionIPC
        let commands = extensionIPC.observeCommands()
        Task { [continuation] in
            for await command in commands {
                switch command {
                case .forkSelectorRequest:
                    continuation.yield()
                }
            }
        }
    }

    func startTunnel(with intent: ServerConnectionIntent) async throws {
        log.debug("Starting tunnel with configuration: \(intent.protocolConfiguration)", category: .connection)

        // Stash the connection spec on the tunnel manager. During connection, the extension can check in with us faster
        // than the Network Extension framework is able to persist the protocol configuration by the time that it pings.
        lastConnectionSpec.withLock { $0 = intent.spec }

        @Dependency(\.vpnManagerRepository) var managerRepository
        // Prepare the configuration - this may prompt the user for VPN permissions
        let manager = try await managerRepository.prepareManager(intent.tunnelProtocol, .connection(intent))

        log.debug("Starting tunnel with bundle identifier: \(optional: manager.providerBundleIdentifier)", category: .connection)
        try Task.checkCancellation()

        #if os(macOS)
            // Eagerly (re)attach the tunnel-data IOSurface for this connection, replacing any previous mapping.
            tunnelDataXPC.reattach()
        #endif

        try manager.session.startTunnel()
    }

    func stopTunnel() async throws {
        @Dependency(\.vpnManagerRepository) var managerRepository
        let managers = try await managerRepository.managers()
        let activeProtocols = managers
            .filter { $0.value.session.status != .disconnected && $0.value.session.status != .invalid }
            .map(\.key)

        if activeProtocols.isEmpty {
            log.warning("stopTunnel: no active tunnel found", category: .connection)
            return
        }

        // Disable on-demand before stopping, to prevent auto-reconnect.
        // Stop all active managers to avoid ending up with concurrent protocol sessions.
        for proto in activeProtocols {
            let onDemand = TunnelConfigurationOperation.reconfiguration([.feature(.tunnel(.onDemand(false)))])
            let manager = try await managerRepository.prepareManager(proto, onDemand)
            log.debug("Stopping tunnel for protocol \(proto)")
            manager.session.stopTunnel()
        }
    }

    func sendProTUN(request: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response {
        do {
            @Dependency(\.vpnManagerRepository) var managerRepository
            guard let manager = try await managerRepository.managers()[.wireGuard(.proTUN)] else {
                throw TunnelManagerError.noManagerFound
            }
            return try await manager.session.sendProTUNRequest(request)
        } catch let error as ProviderMessageError {
            throw error
        } catch {
            log.debug("Failed to send ProTUN request", category: .ipc, metadata: ["error": "\(error)"])
            throw .sendingError(.managerUnavailable(error))
        }
    }

    var status: TunnelState {
        get async throws {
            // Resolve against the latest connection data we've cached from the channel.
            try await resolveState(extensionState: extensionState)
        }
    }

    /// Resolves the TunnelState according to the state reported by the extension (if any) and NetworkExtension itself.
    private func resolveState(extensionState: ExtensionState) async throws -> TunnelState {
        do {
            guard let (tunnelProtocol, activeManager) = try await activeManager() else {
                return .disconnected(nil)
            }
            guard let configuration = activeManager.protocolConfiguration else {
                throw TunnelManagerError.missingConfiguration
            }
            return try await tunnelState(
                session: activeManager.session,
                tunnelProtocol: tunnelProtocol,
                configuration: configuration,
                extensionState: extensionState
            )
        } catch {
            log.error("Failed to resolve tunnel status", category: .connection, metadata: ["error": "\(error)"])
            throw TunnelManagerError.statusResolutionFailed(error)
        }
    }

    var statusStream: AsyncStream<TunnelState> {
        log.debug("Creating TunnelState stream for tunnel observation", category: .connection)
        // Tunnel state is driven by both `NEVPNStatusDidChange` and updates to the tunnel-data peer channel.
        return AsyncStream { continuation in
            let statusTask = Task {
                let notifications = NotificationCenter.default
                    .notifications(named: .NEVPNStatusDidChange)
                    .compactMap { StatusChangePayload.from(statusDidChangeNotification: $0) }
                for await payload in notifications {
                    let state = await self.currentState(afterStatusChange: payload)
                    continuation.yield(state)

                    #if os(macOS)
                        // macOS: ask the extension for the IOSurface region as soon as we begin connecting.
                        switch state {
                        case .connecting:
                            tunnelDataXPC.attach()
                        default:
                            break
                        }
                    #endif
                }
            }
            let connectionDataTask = Task {
                for await extensionState in $extensionState.publisher.values {
                    guard let state = try? await self.resolveState(extensionState: extensionState) else { continue }
                    continuation.yield(state)
                }
            }
            continuation.onTermination = { _ in
                statusTask.cancel()
                connectionDataTask.cancel()
            }
        }
    }

    /// The global tunnel state after an `NEVPNStatusDidChange`. Tries to resolve using `status` at first, and otherwise
    /// tries to reconstruct the tunnel state from the payload sent with the notification. This is to handle IKEv2.
    private func currentState(afterStatusChange payload: StatusChangePayload) async -> TunnelState {
        do {
            return try await status
        } catch {
            log.debug(
                "Failed to resolve global tunnel status; falling back to payload",
                category: .connection,
                metadata: ["error": "\(error)"]
            )
            do {
                return try await tunnelState(
                    session: payload.session,
                    tunnelProtocol: payload.tunnelProtocol,
                    configuration: payload.configuration,
                    extensionState: extensionState
                )
            } catch {
                log.error("Failed to determine connected state: \(error)", category: .connection)
                return .unknown
            }
        }
    }

    private func activeManager() async throws -> (TunnelProtocol, any TunnelProviderManager)? {
        @Dependency(\.vpnManagerRepository) var managerRepository
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

    private func tunnelConfiguration(
        tunnelProtocol: TunnelProtocol,
        configuration: NEVPNProtocol,
        extensionState: ExtensionState
    ) throws -> TunnelConfiguration {
        let peerIDs: [String]
        let connectionSpec: ConnectionSpec

        switch tunnelProtocol {
        case .ike:
            do {
                peerIDs = try configuration.peerIDs
            } catch {
                log.warning("Could not recover IKE peer IDs: \(error)", category: .connection)
                peerIDs = []
            }

            connectionSpec = lastConnectionSpec.withLock { $0 } ?? ConnectionSpec()
        case .wireGuard(.proTUN):
            peerIDs = extensionState.currentPeer.map { [$0.peerID] } ?? []

            if let spec = try (configuration as? NETunnelProviderProtocol)?.connectionSpec {
                connectionSpec = spec
            } else if let spec = lastConnectionSpec.withLock({ $0 }) {
                connectionSpec = spec
            } else {
                throw TunnelDataError.missingConnectionSpec
            }
        case .wireGuard(.go):
            assertionFailure("Unsupported backend")
            peerIDs = []
            connectionSpec = ConnectionSpec()
        }

        return TunnelConfiguration(
            connectionSpec: connectionSpec,
            tunnelProtocol: tunnelProtocol,
            peerIDs: peerIDs
        )
    }

    private func tunnelState(
        session: VPNSession,
        tunnelProtocol: TunnelProtocol,
        configuration: NEVPNProtocol,
        extensionState: ExtensionState
    ) async throws -> TunnelState {
        if case .invalid = session.status { return .invalid }

        // Future: After IKEv2, we can probably get rid of `TunnelState` entirely and just use `ExtensionState`.
        let tunnelConfig = try tunnelConfiguration(
            tunnelProtocol: tunnelProtocol,
            configuration: configuration,
            extensionState: extensionState
        )

        switch session.status {
        case .invalid:
            return .invalid

        case .disconnected:
            if case .disconnected(.tunEstablishError) = extensionState {
                return .disconnected(.tunnelStartFailed(ProTUNConnectionError.tunEstablishFailed))
            }
            return .disconnected(nil)

        case .reasserting:
            return .reasserting(tunnelConfig)

        case .connecting:
            return .connecting(tunnelConfig)

        case .disconnecting:
            return .disconnecting(tunnelConfig)

        case .connected:
            switch tunnelProtocol {
            case .ike:
                // IKEv2 has no Local Agent or extension, so NE reporting `.connected` is authoritative.
                return .connected(tunnelConfig, ikeConnectionData(session: session, configuration: configuration))

            case .wireGuard(.proTUN):
                // The network extension tells the NEPacketTunnelProvider that we're connected before we actually are,
                // so make sure that ProTUN actually says we're connected before advancing the connection state.
                guard case let .connected(peer) = extensionState else { return .connecting(tunnelConfig) }

                return .connected(tunnelConfig, proTUNConnectionData(session: session, peer: peer))

            case .wireGuard(.go):
                throw TunnelDataError.unsupportedBackend
            }

        @unknown default:
            log.error("Unknown NEVPNStatus: \(session.status)", category: .connection)
            return .disconnected(nil)
        }
    }

    /// Since IKE has no LocalAgent channel, we recover the server ID from the configuration. On macOS, the
    /// `.certificate`  auth option can cause the username to be dropped, so we recover it from the connection intent.
    private func ikeConnectionData(session: any VPNSession, configuration: NEVPNProtocol) -> DynamicConnectionData {
        @Dependency(\.date) var date
        let serverID = (try? configuration.ikePeerID) ?? ""
        if serverID.isEmpty {
            log.warning(
                "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID",
                category: .connection
            )
            SentryHelper.shared?.log(message: "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID")
        }

        return DynamicConnectionData(
            currentPeerId: serverID,
            connectionDate: session.connectedDate ?? date.now,
            protocolConnectionData: .ike
        )
    }

    /// Future: when IKEv2 goes away, we can replace `DynamicConnectionData` with the `ExtensionState` enum altogether.
    private func proTUNConnectionData(session: any VPNSession, peer: CurrentPeer?) -> DynamicConnectionData {
        @Dependency(\.date) var date
        return DynamicConnectionData(
            currentPeerId: peer?.peerID,
            connectionDate: session.connectedDate ?? date.now,
            protocolConnectionData: .proTUN(.init(
                transport: peer?.transport ?? .udp,
                serverExitV4: peer?.serverExitV4,
                userISP: peer?.userISP,
                userIP: peer?.userIP
            ))
        )
    }

    func cleanup() async throws {
        @Dependency(\.vpnManagerRepository) var managerRepository
        try await managerRepository.removeAllManagers()
    }
}

public extension ProtocolConnectionData {
    var tunnelProtocol: TunnelProtocol {
        switch self {
        case .ike:
            .ike
        case .proTUN:
            .wireGuard(.proTUN)
        }
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
            .ike
        case let .wireGuard(wgSettings):
            .wireGuard(wgSettings.backend)
        }
    }
}

struct StatusChangePayload {
    let tunnelProtocol: TunnelProtocol
    let session: VPNSession
    let configuration: NEVPNProtocol

    static func from(statusDidChangeNotification notification: Notification) -> Self? {
        guard let session = notification.object as? NEVPNConnection else {
            log.error("NEVPNStatusDidChange notification missing NEVPNConnection", category: .connection)
            return nil
        }

        guard let configuration = session.manager.protocolConfiguration else {
            log.error("Ignoring status NEVPNStatusDidChange (missing configuration)", category: .connection, metadata: ["session": "\(session)", "status": "\(session.status)"])
            return nil
        }

        @Dependency(\.bundleIDClient) var bundleIDClient
        guard let tunnelProtocol = bundleIDClient.tunnelProtocol(configuration) else {
            log.error("Unrecognised bundle identifier in configuration", category: .connection)
            return nil
        }
        return .init(tunnelProtocol: tunnelProtocol, session: session, configuration: configuration)
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

            let config = try ProTUNConfigurationCoder.decode(from: self)
            return config.peers.map(\.id)
        }
    }
}

enum TunnelDataError: Error {
    case unsupportedBackend
    case missingConnectionSpec
}

enum ProTUNConnectionError: FourCharCode, ProtonVPNError {
    case tunEstablishFailed = "PTEF"
}
