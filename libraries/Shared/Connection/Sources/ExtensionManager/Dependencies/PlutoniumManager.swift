//
//  Created on 15/05/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if os(macOS)

    import ComposableArchitecture
    import CoreConnection
    import Dependencies
    import Hermes
    import NetworkExtension
    import VPNAppCore

    @globalActor
    actor PlutoniumActor {
        static let shared = PlutoniumActor()
    }

    public struct PlutoniumManager: DependencyKey, TestDependencyKey {
        public internal(set) var start: () async throws -> Void
        public internal(set) var stop: () async throws -> Void

        private static let bundleId = "ch.protonvpn.mac.Transparent-Proxy"
        private static let descriptionText = "Proton VPN Split tunneling"

        @PlutoniumActor
        private final class ManagerCoordinator {
            @Shared(.plutoniumFeature) private var feature: PlutoniumFeatureToggle
            @Dependency(\.hermesClient) private var hermesClient

            private var rawProviderConfig: [String: Any] {
                get async {
                    let resolvers = hermesClient.currentResolvers.map(\.location)
                    return await feature.toProviderConfigurationDictionary(dnsServers: resolvers)
                }
            }

            private var getManagerTask: Task<NETransparentProxyManager, any Error>?

            func getManager() async throws -> NETransparentProxyManager {
                if let task = getManagerTask {
                    return try await task.value
                }

                let task = Task<NETransparentProxyManager, any Error> {
                    let newManager = try await _getManager()
                    self.getManagerTask = nil
                    return newManager
                }

                getManagerTask = task
                return try await task.value
            }

            private func _getManager() async throws -> NETransparentProxyManager {
                let managers = try await loadPlutoniumManagers()
                let rawProviderConfig = await rawProviderConfig

                switch managers.count {
                case 0:
                    // No existing manager - create new one
                    log.info("No existing manager found, creating new one")
                    _ = try await createNewManager(providerConfig: rawProviderConfig)
                case 1:
                    // Exactly one existing manager - let's check if configuration has changed
                    let manager = managers[0]

                    let currentConf = try PlutoniumProviderConfiguration(from: rawProviderConfig)

                    // if the configurations are the same, let's early exit
                    if let managerConf = manager.plutoniumProviderConfiguration, currentConf == managerConf {
                        break
                    }

                    try await update(configuration: rawProviderConfig, of: manager, context: "existing manager configuration")
                default:
                    // Multiple existing managers - clean up duplicates and keep one
                    log.warning("Found \(managers.count) duplicate managers, cleaning up")

                    // Keep the first one and remove the rest
                    let managerToKeep = managers[0]

                    // Remove duplicate managers
                    try await PlutoniumManager.removeDuplicateManagers(managers[1...])

                    try await update(configuration: rawProviderConfig, of: managerToKeep, context: "kept manager configuration")
                }

                // but we have to reload anyway!
                let reloadedManagers = try await loadPlutoniumManagers()

                guard let manager = reloadedManagers.first else {
                    throw PlutoniumManagerError.noAvailableManager
                }

                return manager
            }

            private func update(
                configuration: [String: Any],
                of manager: NETransparentProxyManager,
                context: String
            ) async throws {
                manager.providerConfiguration = configuration
                try await PlutoniumManager.saveManagerToPreferences(manager, context: context)
            }
        }

        @PlutoniumActor private static let coordinator = ManagerCoordinator()

        private init(
            start: @escaping @PlutoniumActor () async throws -> Void,
            stop: @escaping @PlutoniumActor () async throws -> Void
        ) {
            self.start = start
            self.stop = stop
        }

        public static let liveValue = PlutoniumManager(
            start: {
                let manager = try await coordinator.getManager()
                try manager.connection.startVPNTunnel()
                log.info("Split tunneling started")
            },
            stop: {
                updateAppliedConfiguration()
                let manager = try await coordinator.getManager()
                guard manager.connection.status == .connected else { return }
                manager.connection.stopVPNTunnel()
                log.info("Split tunneling stopped")
            }
        )

        public static let testValue = PlutoniumManager(
            start: {},
            stop: {}
        )

        @PlutoniumActor
        fileprivate static func loadPlutoniumManagers() async throws -> [NETransparentProxyManager] {
            try await NETransparentProxyManager.loadAllFromPreferences().with(bundleId: bundleId)
        }

        @PlutoniumActor
        private static func createNewManager(
            providerConfig: [String: Any]? = nil
        ) async throws -> NETransparentProxyManager {
            let newManager = NETransparentProxyManager()
            let protocolConfig = NETunnelProviderProtocol()
            protocolConfig.providerBundleIdentifier = bundleId
            protocolConfig.serverAddress = "127.0.0.1"
            protocolConfig.providerConfiguration = providerConfig
            newManager.protocolConfiguration = protocolConfig
            newManager.localizedDescription = descriptionText
            newManager.isEnabled = true

            // Save the new manager with proper error handling
            try await saveManagerToPreferences(newManager, context: "new manager")

            return newManager
        }

        @PlutoniumActor
        private static func saveManagerToPreferences(_ manager: NETransparentProxyManager, context: String) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error {
                        log.error("Failed to save \(context): \(error)")
                        continuation.resume(throwing: PlutoniumManagerError.saveFailed(error))
                    } else {
                        log.info("Successfully saved \(context)")
                        continuation.resume(returning: ())
                    }
                }
            }
        }

        @PlutoniumActor
        private static func removeDuplicateManagers(_ managers: some Sequence<NETransparentProxyManager>) async throws {
            // Remove duplicate managers
            for managerToRemove in managers {
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        managerToRemove.removeFromPreferences { error in
                            if let error {
                                log.warning("--- Failed to remove duplicate manager: \(error)")
                                continuation.resume(throwing: error)
                            } else {
                                log.info("--- Successfully removed duplicate manager")
                                continuation.resume(returning: ())
                            }
                        }
                    }
                } catch {
                    log.warning("Error removing duplicate manager: \(error)")
                    // Continue even if removal fails
                }
            }
        }

        private static func updateAppliedConfiguration() {
            @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
            @Shared(.inclusionActivated) var inclusionActivated: PlutoniumActivated
            @Shared(.exclusionActivated) var exclusionActivated: PlutoniumActivated

            @Shared(.plutoniumFeatureApplied) var featureApplied: PlutoniumFeatureToggle
            @Shared(.inclusionActivatedApplied) var inclusionActivatedApplied: PlutoniumActivated
            @Shared(.exclusionActivatedApplied) var exclusionActivatedApplied: PlutoniumActivated

            $featureApplied.withLock { $0 = feature }
            $inclusionActivatedApplied.withLock { $0 = inclusionActivated }
            $exclusionActivatedApplied.withLock { $0 = exclusionActivated }
        }
    }

    public extension DependencyValues {
        var plutoniumManager: PlutoniumManager {
            get { self[PlutoniumManager.self] }
            set { self[PlutoniumManager.self] = newValue }
        }
    }

    extension NETransparentProxyManager {
        var plutoniumProviderConfiguration: PlutoniumProviderConfiguration? {
            providerConfiguration.flatMap { try? PlutoniumProviderConfiguration(from: $0) }
        }

        var providerConfiguration: [String: Any]? {
            get {
                tunnelProtocolConfiguration?.providerConfiguration
            }
            set {
                tunnelProtocolConfiguration?.providerConfiguration = newValue
            }
        }

        var tunnelProtocolConfiguration: NETunnelProviderProtocol? {
            protocolConfiguration as? NETunnelProviderProtocol
        }
    }

    extension Collection where Element: NETransparentProxyManager {
        func with(bundleId: String) -> [NETransparentProxyManager] {
            filter {
                $0.tunnelProtocolConfiguration?.providerBundleIdentifier == bundleId
            }
        }
    }

    public enum PlutoniumManagerError: Error {
        case noAvailableManager
        case saveFailed(Error)

        var localizedDescription: String {
            switch self {
            case let .saveFailed(error):
                "Failed to save transparent proxy manager: \(error.localizedDescription)."
            case .noAvailableManager:
                "No available transparent proxy manager has been found."
            }
        }
    }

#endif
