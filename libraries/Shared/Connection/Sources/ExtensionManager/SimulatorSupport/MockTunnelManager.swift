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
    import Foundation
    import enum NetworkExtension.NEVPNStatus

    import Dependencies

    import CoreConnection
    import Domain
    import ExtensionIPC
    import VPNShared

    final class MockTunnelManager: TunnelManager {
        @Dependency(\.date) var date

        func send(request: ExtensionIPC.WireguardProviderRequest, to _: TunnelMessageTarget) async throws(ExtensionIPC.ProviderMessageError) -> ExtensionIPC.WireguardProviderRequest.Response {
            try await session.send(request)
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
        var session: VPNSession { connection }
        var didStopTunnelCallback: (() -> Void)?
        var shouldGenerateKeysIfMissing: Bool = false

        var connection: VPNSessionMock

        init(connection: VPNSessionMock = .init(status: .disconnected)) {
            self.connection = connection
        }

        func startTunnel(with intent: ServerConnectionIntent) async throws {
            try await Task.sleep(for: tunnelStartDuration)
            try Task.checkCancellation()
            if let tunnelStartErrorToThrow {
                throw tunnelStartErrorToThrow
            }

            if shouldGenerateKeysIfMissing {
                // The real implementation configures the wireguard tunnel configuration with the user's private key.
                // It generates one if it's not present in the keychain. Let's do that same in this mock.
                try generateKeysIfNecessary()
            }

            let server = intent.server
            connection.connectedServerID = server.endpoint.id
            try connection.startTunnel()
        }

        func stopTunnel() async throws {
            didStopTunnelCallback?()
            connection.stopTunnel()
        }

        var status: TunnelState {
            get async throws {
                switch connection.status {
                case .connected:
                    @Dependency(\.date) var date
                    let connectionData = ConnectionData(
                        serverID: connection.connectedServerID,
                        connectionDate: connection.connectedDate ?? date.now,
                        protocolData: .wireGuardGo
                    )
                    return .connected(.wireGuard(.go), connectionData)
                case .invalid: return .invalid
                case .disconnected: return .disconnected(nil)
                case .connecting: return .connecting
                case .reasserting: return .reasserting
                case .disconnecting: return .disconnecting(nil)
                @unknown default: return .disconnected(nil)
                }
            }
        }

        var connectedServerID: String {
            get async throws {
                connection.connectedServerID
            }
        }

        var statusStream: AsyncStream<TunnelState> {
            AsyncStream<TunnelState> { [weak self] continuation in
                guard let self else { return }
                connection.onStatusChange = { [weak self] newStatus in
                    guard let self else { return }
                    let state: TunnelState
                    switch newStatus {
                    case .connected:
                        let connectionData = ConnectionData(
                            serverID: connection.connectedServerID,
                            connectionDate: connection.connectedDate ?? date.now,
                            protocolData: .wireGuardGo
                        )
                        state = .connected(.wireGuard(.go), connectionData)
                    case .invalid: state = .invalid
                    case .disconnected: state = .disconnected(nil)
                    case .connecting: state = .connecting
                    case .reasserting: state = .reasserting
                    case .disconnecting: state = .disconnecting(nil)
                    @unknown default: state = .disconnected(nil)
                    }
                    continuation.yield(state)
                }
                continuation.onTermination = { [weak self] _ in
                    self?.connection.onStatusChange = nil
                }
            }
        }

        func cleanup() async throws {}

        private func generateKeysIfNecessary() throws {
            @Dependency(\.vpnAuthenticationStorage) var keychain
            @Dependency(\.vpnKeysGenerator) var generator
            if keychain.getStoredKeys() == nil {
                log.info("VPN auth storage doesn't contain keys", category: .connection)
                let keys = try generator.generateKeys()
                keychain.store(keys: keys)
                log.info("Generated new keys", category: .connection, metadata: ["keys": "\(keys)"])
            }
        }
    }
#endif
