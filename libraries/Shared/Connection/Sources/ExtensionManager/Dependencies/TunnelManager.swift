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
import NetworkExtension

enum TunnelMessageTarget {
    /// Send to whichever extension is currently active.
    case active
    /// Send to the extension managing the specified tunnel protocol.
    case specific(TunnelProtocol)
}

protocol TunnelManager {
    func startTunnel(with intent: ServerConnectionIntent) async throws
    func stopTunnel() async throws

    func send(request: WireguardProviderRequest, to target: TunnelMessageTarget) async throws(ProviderMessageError) -> WireguardProviderRequest.Response

    func sendProTUN(request: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response

    func cleanup() async throws

    var status: TunnelState { get async throws }
    var statusStream: AsyncStream<TunnelState> { get }
}

@CasePathable
public enum TunnelState: Equatable, Sendable {
    case unknown // Initial state — not yet read from the system
    case invalid // VPN configuration not yet approved by the user
    case disconnected(TunnelConnectionError?)
    case connecting
    case connected(TunnelProtocol, ConnectionData?)
    case reasserting // Briefly re-establishing an existing connection
    case disconnecting(TunnelConnectionError?)
}

public struct ConnectionData: Equatable, Sendable {
    public let serverID: String
    public let connectionDate: Date
    public let protocolData: ProtocolConnectionData

    package init(serverID: String, connectionDate: Date, protocolData: ProtocolConnectionData) {
        self.serverID = serverID
        self.connectionDate = connectionDate
        self.protocolData = protocolData
    }
}

/// Extra information reported by the tunnel.
/// Type of data depends on the connection protocol.
/// Notably, `proTUN` case will be expanded to contain much more information following local agent integration
public enum ProtocolConnectionData: Equatable, Sendable {
    case ike
    case wireGuardGo
    case proTUN
}

enum TunnelManagerKey: DependencyKey {
    #if DEBUG && targetEnvironment(simulator)
        static let liveValue: TunnelManager = {
            log.debug("Simulator: using mocked VPN internals", category: .connection)
            let mockSession = VPNSessionMock(status: .disconnected)
            mockSession.messageHandler = MessageHandler.full
            let manager = MockTunnelManager(connection: mockSession)
            manager.shouldGenerateKeysIfMissing = true
            return manager
        }()
    #else
        static let liveValue: TunnelManager = PacketTunnelManager()
    #endif
}

final class PacketTunnelManager: TunnelManager {
    func startTunnel(with intent: ServerConnectionIntent) async throws {
        log.debug("Starting tunnel with configuration: \(intent.protocolConfiguration)")
        @Dependency(\.vpnManagerRepository) var managerRepository
        // Prepare the configuration - this may prompt the user for VPN permissions
        let manager = try await managerRepository.prepareManager(intent.tunnelProtocol, .connection(intent))

        try Task.checkCancellation()
        try manager.session.startTunnel()
    }

    func stopTunnel() async throws {
        @Dependency(\.vpnManagerRepository) var managerRepository
        let managers = try await managerRepository.managers()
        let activeProtocols = managers
            .filter { $0.value.session.status != .disconnected && $0.value.session.status != .invalid }
            .map(\.key)

        guard !activeProtocols.isEmpty else {
            log.warning("stopTunnel: no active tunnel found", category: .connection)
            return
        }

        // Disable on-demand before stopping, to prevent auto-reconnect.
        // Stop all active managers to avoid ending up with concurrent protocol sessions.
        for proto in activeProtocols {
            let manager = try await managerRepository.prepareManager(proto, .disconnection)
            manager.session.stopTunnel()
        }
    }

    func send(request: WireguardProviderRequest, to target: TunnelMessageTarget) async throws(ProviderMessageError) -> WireguardProviderRequest.Response {
        do {
            let manager: TunnelProviderManager?
            switch target {
            case .active:
                manager = try await activeManager().map(\.1)
            case let .specific(tunnelProtocol):
                @Dependency(\.vpnManagerRepository) var managerRepository
                manager = try await managerRepository.managers()[tunnelProtocol]
            }
            guard let manager else {
                throw TunnelManagerError.noManagerFound
            }
            return try await manager.session.send(request)
        } catch let error as ProviderMessageError {
            throw error
        } catch {
            throw .sendingError(.managerUnavailable(error))
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
            guard let (tunnelProtocol, activeManager) = try await activeManager() else {
                return .disconnected(nil)
            }
            return try await tunnelState(
                session: activeManager.session,
                tunnelProtocol: tunnelProtocol,
                configuration: activeManager.protocolConfiguration
            )
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
            return .connected(payload.tunnelProtocol, nil)
        }
    }

    // We have to consult the network extension to supplement the connected state with additional info
    private func tunnelState(session: VPNSession, tunnelProtocol: TunnelProtocol, configuration: NEVPNProtocol?) async throws -> TunnelState {
        switch session.status {
        case .connected, .reasserting:
            guard let configuration else {
                log.error("Connected manager has no protocol configuration", category: .connection)
                return .disconnected(nil)
            }
            return try await connectedState(session: session, tunnelProtocol: tunnelProtocol, configuration: configuration)
        case .invalid: return .invalid
        case .disconnected: return .disconnected(nil)
        case .connecting: return .connecting
        case .disconnecting: return .disconnecting(nil)
        @unknown default:
            log.error("Unknown NEVPNStatus: \(session.status)", category: .connection)
            return .disconnected(nil)
        }
    }

    private func connectedState(session: any VPNSession, tunnelProtocol: TunnelProtocol, configuration: NEVPNProtocol) async throws -> TunnelState {
        @Dependency(\.date) var date

        let connectionDate = session.connectedDate ?? date.now

        switch tunnelProtocol {
        case .ike:
            // IKE bypasses Local Agent, so tunnel-up is sufficient for the user-facing
            // `.connected` state to advance. We still try to recover the server ID from the
            // configuration (via `ikePeerID`) but tolerate failure: if the username has been
            // dropped or malformed (e.g. macOS occasionally drops it across save/load for
            // `.certificate` auth), we'd otherwise stall in `ExtensionManagerFeature`'s
            // `guard let connectionData` (TunnelState `.connected(_, nil)` is rejected there).
            // Falling back to an empty serverID lets the connection advance; downstream code
            // that needs the server uses `currentIntent?.serverIntent.server` from
            // `ConnectionFeature`, not this field.
            let serverID = (try? configuration.ikePeerID) ?? ""
            if serverID.isEmpty {
                log.warning(
                    "Could not recover IKE peer ID from configuration; advancing connected state with empty serverID",
                    category: .connection
                )
            }
            let connectionData = ConnectionData(
                serverID: serverID,
                connectionDate: connectionDate,
                protocolData: .ike
            )
            return .connected(tunnelProtocol, connectionData)

        case .wireGuard(.go):
            let serverID: String = try await {
                #if os(macOS)
                    let configurationServerID = (configuration as? NETunnelProviderProtocol)?
                        .connectedServerIpId
                        .flatMap { $0.isEmpty ? nil : $0 }

                    if let ipcServerID = try? await fetchServerIDViaIPC(session: session) {
                        if let configurationServerID, configurationServerID != ipcServerID {
                            log.debug(
                                "Connected server ID mismatch between IPC and configuration; using IPC. configurationServerID: \(configurationServerID), ipcServerID: \(ipcServerID)",
                                category: .connection
                            )
                        }
                        return ipcServerID
                    }
                    if let configurationServerID {
                        return configurationServerID
                    }
                    return try await fetchServerIDViaIPC(session: session)
                #else
                    return try await fetchServerIDViaIPC(session: session)
                #endif
            }()

            let connectionData = ConnectionData(
                serverID: serverID,
                connectionDate: connectionDate,
                protocolData: .wireGuardGo
            )
            return .connected(tunnelProtocol, connectionData)

        case .wireGuard(.proTUN):
            let response: ProTUNMessage.Response = try await session.sendProTUNRequest(.init(payload: .getCurrentPeerID))
            switch response.payload {
            case let .currentPeerID(.success(peerId)):
                let connectionData = ConnectionData(
                    serverID: peerId,
                    connectionDate: connectionDate,
                    protocolData: .proTUN // This case will be extended in the future to hold proTUN specific data & local agent state
                )
                return .connected(tunnelProtocol, connectionData)
            case let .currentPeerID(.failure(error)):
                log.error("ProTUN-Extension denied getCurrentPeerID: \(error)", category: .connection)
                throw TunnelManagerError.protunIPC(error.localizedDescription)
            case let .error(.unsupported(_, _, reason)):
                throw TunnelManagerError.protunIPC("Unsupported message with version mismatch: \(reason)")
            default:
                throw TunnelManagerError.ipc(.getCurrentServerId, nil)
            }
        }
    }

    private func fetchServerIDViaIPC(session: any VPNSession) async throws -> String {
        guard case let .ok(data?) = try await session.send(.getCurrentServerId),
              let serverID = String(data: data, encoding: .utf8),
              !serverID.isEmpty else {
            throw TunnelManagerError.ipc(.getCurrentServerId, nil)
        }
        return serverID
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
        case .wireGuardGo:
            .wireGuard(.go)
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
