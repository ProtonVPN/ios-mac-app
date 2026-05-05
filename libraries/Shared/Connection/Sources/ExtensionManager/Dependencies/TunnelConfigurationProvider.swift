//
//  Created on 06/03/2025.
//
//  Copyright (c) 2025 Proton AG
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

import CoreConnection
import Dependencies
import Domain
import Foundation
import NetworkExtension

/// Manages NEVPNManagers (creating/loading, updating, saving, removing).
///
/// This protocol focuses solely on CRUD operations involving these managers, and does not interact with VPN sessions.
/// It provides the necessary `NEVPNManager` instances (often inherited from) that can then be used to interact sessions.
///
/// It essentially is a manager for managers
struct VPNManagerRepository {
    /// Returns all VPN configurations that have been saved to the system, keyed by tunnel protocol.
    /// Results are cached after the first load; use `removeAllManagers` to clear the cache.
    var managers: @Sendable () async throws -> [TunnelProtocol: any TunnelProviderManager]

    /// Prepare (update, save and reload) a manager for a specific tunnel operation (connection or disconnection).
    ///
    /// - Parameter operation: The tunnel operation to configure for
    /// - Returns: A configured and saved `TunnelProviderManager` ready to be used
    var prepareManager: @Sendable (_ proto: TunnelProtocol, _ operation: TunnelConfigurationOperation) async throws -> TunnelProviderManager

    /// Remove all VPN configurations from the system and invalidate the manager cache.
    var removeAllManagers: @Sendable () async throws -> Void
}

/// Default implementation of TunnelConfigurationProvider.
actor VPNManagerRepositoryImplementation {
    private var cachedManagers: [TunnelProtocol: any TunnelProviderManager]?
    private var loadTask: Task<[TunnelProtocol: any TunnelProviderManager], Error>?

    private var configurationChangeTask: Task<Void, Never>?

    init() {
        self.configurationChangeTask = Task {
            @Dependency(\.bundleIDClient) var bundleIDClient
            for await notification in NotificationCenter.default.notifications(named: .NEVPNConfigurationChange) {
                guard let manager = notification.object as? NEVPNManager else {
                    log.error("NEVPNConfigurationChange notification missing NEVPNManager", category: .connection)
                    continue
                }

                guard let configuration = manager.protocolConfiguration else {
                    log.error("Ignoring NEVPNConfigurationChange (missing configuration)", category: .connection)
                    continue
                }

                guard let tunnelProtocol = bundleIDClient.tunnelProtocol(configuration) else {
                    log.assertionFailure("Unrecognised bundle identifier in configuration", category: .connection)
                    continue
                }

                log.debug("NEVPNConfigurationChange", category: .connection, metadata: ["tunnelProtocol": "\(tunnelProtocol)"])
                // At this point, we could invalidate the cached manager, but since we already reload configurations
                // after saving them, this shouldn't be necessary outside of the user removing the configuration.
                // The NEVPNStatusDidChange notification is good enough for us to realise we get disconnected when the
                // user removes the configuration while connected, and otherwise we recreate it on the next
                // connection with no issues.
            }
        }
    }

    deinit {
        configurationChangeTask?.cancel()
        configurationChangeTask = nil
    }

    func managers() async throws -> [TunnelProtocol: any TunnelProviderManager] {
        if let cachedManagers {
            return cachedManagers
        }
        if let loadTask {
            log.debug("Manager loading already in progress, ")
            return try await loadTask.value
        }
        let task = Task<[TunnelProtocol: any TunnelProviderManager], Error> {
            @Dependency(\.tunnelProviderManagerFactory) var managerFactory
            @Dependency(\.bundleIDClient) var bundleIDClient
            let managers = try await managerFactory.loadFromPreferences()
            return managers.reduce(into: [:]) { result, manager in
                guard let config = manager.protocolConfiguration else {
                    log.warning("Loaded manager has no configuration", category: .connection, metadata: ["manager": "\(manager)"])
                    return
                }
                guard let proto = bundleIDClient.tunnelProtocol(config) else {
                    log.assertionFailure("Loaded manager has unknown tunnel protocol", category: .connection, metadata: ["config": "\(config)"])
                    return
                }
                result[proto] = manager
            }
        }
        loadTask = task
        let result = try await task.value
        cachedManagers = result
        loadTask = nil
        return result
    }

    func prepareManager(of tunnelProtocol: TunnelProtocol, for operation: TunnelConfigurationOperation) async throws -> TunnelProviderManager {
        @Dependency(\.tunnelProviderConfigurator) var configurator
        @Dependency(\.tunnelProviderManagerFactory) var managerFactory

        var manager: any TunnelProviderManager
        if let cached = try await managers()[tunnelProtocol] {
            manager = cached
        } else {
            let type: ProtocolType = (tunnelProtocol == .ike) ? .ike : .custom
            manager = managerFactory.create(type)
        }

        // Configure the manager for the operation
        try await configurator.configure(&manager, for: operation)
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        // Update cache
        cachedManagers?[tunnelProtocol] = manager

        return manager
    }

    func removeAllManagers() async throws {
        @Dependency(\.tunnelProviderManagerFactory) var managerFactory
        try await managerFactory.removeAll()
        invalidate()
    }

    private func invalidate() {
        cachedManagers = nil
        loadTask?.cancel()
        loadTask = nil
    }
}

extension VPNManagerRepository: DependencyKey {
    static let liveValue: VPNManagerRepository = {
        let repository = VPNManagerRepositoryImplementation()
        return VPNManagerRepository(
            managers: { try await repository.managers() },
            prepareManager: { proto, operation in try await repository.prepareManager(of: proto, for: operation) },
            removeAllManagers: { try await repository.removeAllManagers() }
        )
    }()
}

extension DependencyValues {
    var vpnManagerRepository: VPNManagerRepository {
        get { self[VPNManagerRepository.self] }
        set { self[VPNManagerRepository.self] = newValue }
    }
}
