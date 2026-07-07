//
//  Created on 31/05/2024.
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

#if DEBUG
    import CoreConnection
    import Dependencies
    import Domain
    import ExtensionIPC
    import ExtensionSync
    import Foundation
    import enum NetworkExtension.NEVPNStatus
    import Sharing
    import VPNShared

    final class MockTunnelManager: TunnelManager {
        @Dependency(\.date) var date

        /// The connection state the simulator's `VPNSessionMock` publishes, used to fake the connected peer in the UI.
        @SharedReader(.mockExtensionState) private var publishedExtensionState

        /// The published peer, once the mock has reported a connection.
        private var publishedPeer: CurrentPeer? {
            guard case let .connected(peer) = publishedExtensionState else { return nil }
            return peer
        }

        func sendProTUN(request: Domain.ProTUNMessage.Request) async throws(ExtensionIPC.ProviderMessageError) -> Domain.ProTUNMessage.Response {
            do {
                return try await session.sendProTUNRequest(request)
            } catch {
                throw .protunError(message: "\(error)")
            }
        }

        var tunnelStartErrorToThrow: Error?
        var tunnelStartDuration: Duration = .seconds(0)
        var session: VPNSession {
            connection
        }

        var didStopTunnelCallback: (() -> Void)?

        var connection: VPNSessionMock

        var forkRequestsStream: AsyncStream<Void> {
            .finished
        }

        init(connection: VPNSessionMock = .init(status: .disconnected)) {
            self.connection = connection
        }

        func startTunnel(with intent: ServerConnectionIntent) async throws {
            try await Task.sleep(for: tunnelStartDuration)
            try Task.checkCancellation()
            if let tunnelStartErrorToThrow {
                throw tunnelStartErrorToThrow
            }

            let server = intent.server
            connection.connectedServerID = server.endpoint.id
            try connection.startTunnel()
        }

        func startZeroPeerTunnel() async throws {
            try await Task.sleep(for: tunnelStartDuration)
            try Task.checkCancellation()
            try connection.startTunnel()
        }

        func stopTunnel() async throws {
            didStopTunnelCallback?()
            connection.stopTunnel()
        }

        var status: TunnelState {
            get async throws {
                state(from: connection.status)
            }
        }

        private func state(from _: NEVPNStatus) -> TunnelState {
            let tunnelConfig = TunnelConfiguration(connectionSpec: ConnectionSpec(), tunnelProtocol: .wireGuard, peerIDs: ["peer-id"])
            switch connection.status {
            case .connected:
                // Fake the connected peer from the value `VPNSessionMock` published, falling back to the "peer-id"
                // default when nothing has been published (e.g. a test that sets `.connected` without starting).
                let connectionData = DynamicConnectionData(
                    currentPeerId: publishedPeer?.peerID ?? "peer-id",
                    connectionDate: date.now,
                    protocolConnectionData: .proTUN(.init(
                        transport: publishedPeer?.transport ?? .udp,
                        serverExitV4: publishedPeer?.serverExitV4,
                        userISP: publishedPeer?.userISP,
                        userIP: publishedPeer?.userIP
                    ))
                )
                return .connected(tunnelConfig, connectionData)
            case .invalid: return .invalid
            case .disconnected: return .disconnected(nil)
            case .connecting: return .connecting(tunnelConfig)
            case .reasserting: return .reasserting(tunnelConfig)
            case .disconnecting: return .disconnecting(tunnelConfig)
            @unknown default: return .disconnected(nil)
            }
        }

        var connectedServerID: String {
            get async throws {
                connection.connectedServerID
            }
        }

        var statusStream: AsyncStream<Result<TunnelState, ExtensionError>> {
            AsyncStream<Result<TunnelState, ExtensionError>> { [weak self] continuation in
                self?.connection.onStatusChange = { [weak self] newStatus in
                    guard let self else { return }
                    let state = state(from: newStatus)
                    continuation.yield(.success(state))
                }
                continuation.onTermination = { [weak self] _ in
                    self?.connection.onStatusChange = nil
                }
            }
        }

        func cleanup() async throws {}
    }
#endif
