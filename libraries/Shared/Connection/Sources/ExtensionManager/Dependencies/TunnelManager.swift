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
        guard let (proto, _) = try await activeManager() else {
            log.warning("stopTunnel: no active tunnel found", category: .connection)
            return
        }

        // Disable on-demand before stopping, to prevent auto-reconnect
        @Dependency(\.vpnManagerRepository) var managerRepository
        let manager = try await managerRepository.prepareManager(proto, .disconnection)
        manager.session.stopTunnel()
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
        return NotificationCenter.default.notifications(named: .NEVPNStatusDidChange)
            .compactMap { StatusChangePayload.from(statusDidChangeNotification: $0) }
            .map { await self.tunnelState(from: $0) }
            .eraseToStream()
    }

    private func activeManager() async throws -> (TunnelProtocol, any TunnelProviderManager)? {
        @Dependency(\.vpnManagerRepository) var managerRepository
        return try await managerRepository.managers().first(where: {
            $0.value.session.status != .disconnected && $0.value.session.status != .invalid
        })
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
            let connectionData = try ConnectionData(
                serverID: configuration.ikePeerID,
                connectionDate: connectionDate,
                protocolData: .ike
            )
            return .connected(tunnelProtocol, connectionData)

        case .wireGuard(.go):
            guard case let .ok(data?) = try await session.send(.getCurrentServerId),
                  let serverID = String(data: data, encoding: .utf8) else {
                throw TunnelManagerError.ipc(.getCurrentServerId, nil)
            }

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
    /// Temporary helper for retrieving the peer ID from IKE configurations
    var ikePeerID: String {
        get throws {
            // VPNAPPL-3466: Smarter way to encode the username, without conflicting with other features
            guard let username, let index = username.lastIndex(of: "+") else {
                throw TunnelManagerError.malformedConfiguration
            }
            return String(username.suffix(from: index))
        }
    }
}
