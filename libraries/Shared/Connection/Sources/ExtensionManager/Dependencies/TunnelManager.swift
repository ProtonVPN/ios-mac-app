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

import CoreConnection
import struct Domain.ServerConnectionIntent
import ExtensionIPC

protocol TunnelManager {
    func startTunnel(with intent: ServerConnectionIntent) async throws
    func stopTunnel() async throws
    func removeManagers() async throws

    var session: VPNSession { get async throws }
    var connectedServer: LogicalServerInfo { get async throws }
    var status: NEVPNStatus { get async throws }
    var statusStream: AsyncStream<NEVPNStatus> { get async throws }
}

@available(iOS 16, *)
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

    private var stepDelay: Duration? {
        // This is needed to let the loading complete, there seems to be a race in older versions of the
        // NetworkExtension framework. I know it's terrible but it's a system API. Sad!
        //
        // We tried this with 200ms, 250ms, 750ms, and finally a full second. Nobody is happy about this.
        guard #available(iOS 17, tvOS 17, macOS 14, *) else {
            return .seconds(1)
        }

        return nil
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

        if let stepDelay {
            try await Task.sleep(for: stepDelay)
        }

        try await manager.loadFromPreferences()

        if let stepDelay {
            try await Task.sleep(for: stepDelay)
        }

        cachedLoadedManager = manager
        return manager
    }

    func startTunnel(with intent: ServerConnectionIntent) async throws {
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

    var connectedServer: LogicalServerInfo {
        get async throws {
            let response = try await loadedManager.session.send(WireguardProviderRequest.getCurrentLogicalAndServerId)
            guard case let .ok(data) = response, let data, let ids = String(data: data, encoding: .utf8) else {
                log.error("Error decoding getCurrentLogicalAndServerId response", category: .connection)
                throw TunnelManagerError.ipc(.getCurrentLogicalAndServerId, nil)
            }
            let id = ids.components(separatedBy: ";")
            guard id.count == 2 else {
                log.error("Unexpected number of elements in getCurrentLogicalAndServerId repsonse (expected 2, got \(id.count))", category: .connection)
                throw TunnelManagerError.ipc(.getCurrentLogicalAndServerId, nil)
            }

            return LogicalServerInfo(logicalID: id[0], serverID: id[1])
        }
    }

    var statusStream: AsyncStream<NEVPNStatus> {
        get async throws {
            let session = try await loadedManager.session
            let statusChangedNotifications = NotificationCenter.default
                .notifications(named: Notification.Name.NEVPNStatusDidChange, object: session)
                .map { _ in session.status }

            return AsyncStream(statusChangedNotifications)
        }
    }

    func removeManagers() async throws {
        try await managerFactory.removeAll()
    }
}

enum TunnelManagerError: Error {
    case ipc(WireguardProviderRequest, Error?)
}

@available(iOS 16, *)
extension DependencyValues {
    var tunnelManager: TunnelManager {
        get { self[TunnelManagerKey.self] }
        set { self[TunnelManagerKey.self] = newValue }
    }
}
