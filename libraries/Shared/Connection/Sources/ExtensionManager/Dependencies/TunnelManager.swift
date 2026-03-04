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

import Foundation
import enum NetworkExtension.NEVPNStatus

import Dependencies
import Domain

import CoreConnection
import struct Domain.ServerConnectionIntent
import ExtensionIPC

protocol TunnelManager {
    func startTunnel(with intent: ServerConnectionIntent) async throws
    func stopTunnel() async throws
    func removeManagers() async throws

    var session: VPNSession { get async throws }
    var connectedServerID: String { get async throws }
    var status: NEVPNStatus { get async throws }
    var statusStream: AsyncStream<NEVPNStatus> { get async throws }
}

enum TunnelManagerKey: DependencyKey {
    #if targetEnvironment(simulator)
        static let liveValue: TunnelManager = {
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
    @Dependency(\.tunnelProviderManagerFactory) var managerFactory
    @Dependency(\.tunnelProviderConfigurator) var configurator
    @Dependency(\.bundleIDClient) var bundleID

    private var cachedLoadedManager: TunnelProviderManager?

    /// Creates and loads a new `TunnelProviderManager`.
    private func loadManager() async throws -> TunnelProviderManager {
        let bundleID = bundleID.bundleIdentifierForTarget()
        let manager = try await managerFactory.loadManager(forProviderBundleID: bundleID)
        cachedLoadedManager = manager
        return manager
    }

    /// Returning a loaded manager is handy since actions like connecting and updating protocol settings require the
    /// manager to have been loaded at least once after the app has been launched.
    ///
    /// Relevant Apple Developer documentation:
    /// > You must call `loadFromPreferencesWithCompletionHandler` at least once before calling this method the first
    /// time after your app launches.
    /// > [saveToPreferences(completionHandler:)](https://developer.apple.com/documentation/networkextension/nevpnmanager/1405985-savetopreferences)
    private var loadedManager: TunnelProviderManager {
        get async throws {
            if let cachedLoadedManager {
                return cachedLoadedManager
            }

            return try await loadManager()
        }
    }

    private func updateTunnel(for operation: TunnelConfigurationOperation) async throws -> TunnelProviderManager {
        var manager = try await loadedManager
        try await configurator.configure(&manager, for: operation)
        try await manager.saveToPreferences()

        try await manager.loadFromPreferences()

        cachedLoadedManager = manager
        return manager
    }

    func startTunnel(with intent: ServerConnectionIntent) async throws {
        // The following call may prompt the user to give permissions to our app to modify VPN configs
        let manager = try await updateTunnel(for: .connection(intent))
        try Task.checkCancellation()
        try manager.session.startTunnel()
    }

    func stopTunnel() async throws {
        let manager = try await updateTunnel(for: .disconnection)
        manager.session.stopTunnel()
    }

    var session: VPNSession {
        get async throws {
            try await loadedManager.session
        }
    }

    var status: NEVPNStatus {
        get async throws {
            try await session.status
        }
    }

    var connectedServerID: String {
        get async throws {
            let manager = try await loadedManager
            if manager.isProTUN {
                let response: ProTUNMessage.Response = try await manager.session.sendProTUNRequest(.init(payload: .getCurrentPeerID))
                switch response.payload {
                case let .currentPeerID(.success(peerId)):
                    return peerId
                case let .currentPeerID(.failure(error)):
                    log.error("ProTUN-Extension denied getCurrentPeerID: \(error)", category: .connection)
                    throw TunnelManagerError.protunIPC(error.localizedDescription)
                case let .error(.unsupported(_, _, reason)):
                    throw TunnelManagerError.protunIPC("Unsupported message with version mismatch: \(reason)")
                default:
                    throw TunnelManagerError.ipc(.getCurrentServerId, nil)
                }
            }
            let response = try await manager.session.send(WireguardProviderRequest.getCurrentServerId)
            guard case let .ok(data) = response, let data, let serverID = String(data: data, encoding: .utf8) else {
                log.error("Error decoding getCurrentLogicalAndServerId response", category: .connection)
                throw TunnelManagerError.ipc(.getCurrentServerId, nil)
            }
            return serverID
        }
    }

    var statusStream: AsyncStream<NEVPNStatus> {
        get async throws {
            log.debug("Creating NEVPNStatus stream for tunnel observation", category: .connection)
            let session = try await loadedManager.session
            let statusChangedNotifications = NotificationCenter.default
                .notifications(named: Notification.Name.NEVPNStatusDidChange, object: session)
                .map { _ in session.status }

            return AsyncStream(UncheckedSendable(statusChangedNotifications))
        }
    }

    func removeManagers() async throws {
        try await managerFactory.removeAll()
    }
}

enum TunnelManagerError: Error {
    case ipc(WireguardProviderRequest, Error?)
    case protunIPC(String)
}

extension DependencyValues {
    var tunnelManager: TunnelManager {
        get { self[TunnelManagerKey.self] }
        set { self[TunnelManagerKey.self] = newValue }
    }
}
