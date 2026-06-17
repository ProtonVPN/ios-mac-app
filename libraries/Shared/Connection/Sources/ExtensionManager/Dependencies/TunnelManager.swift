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
import CoreConnection
import Dependencies
import Domain
import ExtensionIPC
import Foundation
import IPCErgonomics
import LocalAgent
import LocalAgentIPC
import NetworkExtension
import VPNAppCore
import VPNCoreCommon
import VPNCoreTypes

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
    /// The ID of the peer we are connected to
    public let currentPeerId: String

    /// The date at which the tunnel first entered the `connected` state.
    public let connectionDate: Date

    /// Protocol specific data
    public let protocolConnectionData: ProtocolConnectionData

    public init(currentPeerId: String, connectionDate: Date, protocolConnectionData: ProtocolConnectionData) {
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

    private let forkRequestsContinuation: AsyncStream<Void>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.forkRequestsStream = stream
        self.forkRequestsContinuation = continuation

        IPCNotifications.observe(.extensionForkSelectorRequest) { [weak self] in
            self?.forkRequestsContinuation.yield()
        }
    }

    func startTunnel(with intent: ServerConnectionIntent) async throws {
        log.debug("Starting tunnel with configuration: \(intent.protocolConfiguration)", category: .connection)
        @Dependency(\.vpnManagerRepository) var managerRepository
        // Prepare the configuration - this may prompt the user for VPN permissions
        let manager = try await managerRepository.prepareManager(intent.tunnelProtocol, .connection(intent))

        log.debug("Starting tunnel with bundle identifier: \(optional: manager.providerBundleIdentifier)", category: .connection)
        try Task.checkCancellation()
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
                    configuration: configuration
                )
            } catch {
                print(error)
                throw NSError(domain: "failed to fetch status", code: 2334)
            }
        }
    }

    var statusStream: AsyncStream<TunnelState> {
        log.debug("Creating TunnelState stream for tunnel observation", category: .connection)
        // Each notification resolves via `currentTunnelState(after:)`, which reads the
        // active manager (`try await status`) and only falls back to the payload on
        // failure. A payload-only approach is unreliable on macOS for IKE: the shared
        // `NEVPNManager`'s `protocolConfiguration` can transiently be nil during a status
        // change, causing the notification to be dropped and the state to never reach
        // `.connected`. The cached managers from `vpnManagerRepository` expose the IKE
        // configuration in a stable way.
        return UncheckedSendable(
            NotificationCenter.default
                .notifications(named: .NEVPNStatusDidChange)
                .compactMap { StatusChangePayload.from(statusDidChangeNotification: $0) }
                .map { await self.currentTunnelState(after: $0) }
        )
        .eraseToStream()
    }

    private func currentTunnelState(after payload: StatusChangePayload) async -> TunnelState {
        do {
            return try await status
        } catch {
            log.debug(
                "Failed to resolve global tunnel status; falling back to payload",
                category: .connection,
                metadata: ["error": "\(error)"]
            )
            return await tunnelState(from: payload)
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

    private func tunnelState(from payload: StatusChangePayload) async -> TunnelState {
        do {
            return try await tunnelState(
                session: payload.session,
                tunnelProtocol: payload.tunnelProtocol,
                configuration: payload.configuration
            )
        } catch {
            log.error("Failed to determine connected state: \(error)", category: .connection)
            return .unknown
        }
    }

    private func tunnelState(after payload: StatusChangePayload) async -> TunnelState {
        do {
            return try await status
        } catch {
            log.error("Failed to resolve global tunnel status: \(error)", category: .connection)
            return await tunnelState(from: payload)
        }
    }

    private func staticTunnelData(
        tunnelProtocol: TunnelProtocol,
        configuration: NEVPNProtocol
    ) throws -> TunnelConfiguration {
        let peerIDs: [String]
        do {
            peerIDs = try configuration.peerIDs
        } catch {
            // For IKEv2 we can still advance here
            guard tunnelProtocol == .ike else { throw error }
            log.warning("Could not recover IKE peer IDs from configuration", category: .connection)
            peerIDs = []
        }
        let connectionSpec: ConnectionSpec
        if let spec = try configuration.connectionSpec {
            connectionSpec = spec
        } else if tunnelProtocol == .ike {
            // IKEv2 can't provide `configuration.connectionSpec`, we need to pass a `fallbackSpec`
            connectionSpec = ConnectionSpec()
        } else {
            throw TunnelDataError.missingConnectionSpec
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
        configuration: NEVPNProtocol
    ) async throws -> TunnelState {
        switch session.status {
        case .invalid:
            return .invalid

        case .disconnected:
            return .disconnected(nil)

        case .reasserting:
            return try .reasserting(staticTunnelData(tunnelProtocol: tunnelProtocol, configuration: configuration))

        case .connecting:
            return try .connecting(staticTunnelData(tunnelProtocol: tunnelProtocol, configuration: configuration))

        case .disconnecting:
            return try .disconnecting(staticTunnelData(tunnelProtocol: tunnelProtocol, configuration: configuration))

        case .connected:
            let tunnelConfig = try staticTunnelData(tunnelProtocol: tunnelProtocol, configuration: configuration)
            return try await .connected(
                tunnelConfig,
                dynamicConnectionData(session: session, tunnelProtocol: tunnelProtocol, configuration: configuration)
            )

        @unknown default:
            log.error("Unknown NEVPNStatus: \(session.status)", category: .connection)
            return .disconnected(nil)
        }
    }

    private func dynamicConnectionData(
        session: any VPNSession,
        tunnelProtocol: TunnelProtocol,
        configuration: NEVPNProtocol?
    ) async throws -> DynamicConnectionData {
        @Dependency(\.date) var date
        let connectionDate = session.connectedDate ?? date.now

        switch tunnelProtocol {
        case .ike:
            // IKE bypasses Local Agent, so tunnel-up is sufficient for the user-facing
            // `.connected` state to advance. We try to recover the server ID from the
            // configuration (via `ikePeerID`) but tolerate failure: macOS occasionally drops the
            // username across save/load for `.certificate` auth. Falling back to an empty serverID
            // lets the connection advance; the Connection layer resolves the server and spec from
            // the in-app intent (`ConnectionState.init(tunnel:fallbackSpec:)`) when this is empty.
            let serverID = (try? configuration?.ikePeerID) ?? ""
            if serverID.isEmpty {
                log.warning(
                    "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID",
                    category: .connection
                )
                SentryHelper.shared?.log(message: "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID")
            }
            return DynamicConnectionData(
                currentPeerId: serverID,
                connectionDate: connectionDate,
                protocolConnectionData: .ike
            )

        case .wireGuard(.go):
            throw TunnelDataError.unsupportedBackend

        case .wireGuard(.proTUN):
            @Dependency(\.localAgent) var localAgent
            // The response arrives asynchronously as a `LocalAgent.Event.features` event
            // TODO: ProTUN: use mmap to pull features immediately
            try localAgent.postRequestToExtension(.getFeatures)
            let response: ProTUNMessage.Response = try await session.sendProTUNRequest(.init(payload: .getCurrentPeer))
            switch response.payload {
            case let .currentPeer(.success(peer)):
                return DynamicConnectionData(
                    currentPeerId: peer.peerID,
                    connectionDate: connectionDate,
                    protocolConnectionData: .proTUN(.init(
                        transport: peer.transport,
                        serverExitV4: peer.serverExitV4,
                        userISP: peer.userISP,
                        userIP: peer.userIP
                    ))
                )
            case let .currentPeer(.failure(error)):
                log.error("ProTUN-Extension denied getCurrentPeerID: \(error)", category: .connection)
                throw TunnelManagerError.protunIPC(error.localizedDescription)
            case let .error(.unsupported(_, _, reason)):
                throw TunnelManagerError.protunIPC("Unsupported message with version mismatch: \(reason)")
            default:
                throw TunnelManagerError.ipc(.getCurrentServerId, nil)
            }
        }
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
    /// The user's connection intent, decoded from the provider configuration written by `WireguardConfigurator.encodeProTUNConfiguration`.
    /// Not available for IKE configurations, which use `NEVPNProtocolIKEv2` and carry no provider dictionary.
    var connectionSpec: ConnectionSpec? {
        get throws {
            guard let providerProtocol = self as? NETunnelProviderProtocol else { return nil }
            guard let data = providerProtocol.providerConfiguration?["connectionSpec"] as? Data else { return nil }
            return try JSONDecoder().decode(ConnectionSpec.self, from: data)
        }
    }

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
