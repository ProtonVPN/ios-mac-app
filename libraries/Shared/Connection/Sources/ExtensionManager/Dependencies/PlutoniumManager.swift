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

    public struct PlutoniumManager: DependencyKey, TestDependencyKey {
        public var start: () async throws -> Void
        public var stop: () async throws -> Void

        private static let bundleId = "ch.protonvpn.mac.Transparent-Proxy"
        private static let descriptionText = "Proton VPN Split tunneling"

        private actor ManagerCoordinator {
            private var cachedManager: NETransparentProxyManager?

            func getManager(providerConfig: [String: Any]? = nil) async throws -> NETransparentProxyManager {
                // If we have a cached manager, update its config and return it
                if let cachedManager {
                    if let protocolConfig = cachedManager.protocolConfiguration as? NETunnelProviderProtocol {
                        protocolConfig.providerConfiguration = providerConfig
                        cachedManager.protocolConfiguration = protocolConfig
                    }
                    try await PlutoniumManager.saveManagerToPreferences(cachedManager, context: "cached manager configuration")
                    return cachedManager
                }

                // No cached manager, load from preferences
                let manager = try await PlutoniumManager.loadOrCreateManager(providerConfig: providerConfig)
                cachedManager = manager
                return manager
            }
        }

        private static let coordinator = ManagerCoordinator()

        private init(
            start: @escaping () async throws -> Void,
            stop: @escaping () async throws -> Void
        ) {
            self.start = start
            self.stop = stop
        }

        public static let liveValue = PlutoniumManager(
            start: {
                @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
                @Dependency(\.hermesClient) var hermesClient
                let manager = try await coordinator.getManager(
                    providerConfig: feature
                        .toProviderConfigurationDictionary(dnsServers: hermesClient.currentResolvers.map(\.location))
                )
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

        private static func loadOrCreateManager(providerConfig: [String: Any]? = nil) async throws -> NETransparentProxyManager {
            // 1. load all saved managers
            let managers = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[NETransparentProxyManager], Error>) in
                NETransparentProxyManager.loadAllFromPreferences { list, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: list ?? [])
                    }
                }
            }

            // 2. Find managers with the same bundle ID
            let managersWithSameBundleId = managers.filter { manager in
                (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleId
            }

            // 3. Handle different scenarios
            switch managersWithSameBundleId.count {
            case 0:
                // No existing manager - create new one
                log.info("No existing manager found, creating new one")
                return try await createNewManager(providerConfig: providerConfig)

            case 1:
                // Exactly one existing manager - reuse it
                let existingManager = managersWithSameBundleId[0]

                // Update configuration if needed
                if let protocolConfig = existingManager.protocolConfiguration as? NETunnelProviderProtocol {
                    protocolConfig.providerConfiguration = providerConfig
                    existingManager.protocolConfiguration = protocolConfig
                }

                // Save the updated configuration
                try await saveManagerToPreferences(existingManager, context: "existing manager configuration")

                return existingManager

            default:
                // Multiple existing managers - clean up duplicates and keep one
                log.warning("Found \(managersWithSameBundleId.count) duplicate managers, cleaning up")

                // Keep the first one and remove the rest
                let managerToKeep = managersWithSameBundleId[0]
                let managersToRemove = Array(managersWithSameBundleId.dropFirst())

                // Remove duplicate managers
                for managerToRemove in managersToRemove {
                    do {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            managerToRemove.removeFromPreferences { error in
                                if let error {
                                    log.warning("Failed to remove duplicate manager: \(error)")
                                    continuation.resume(throwing: error)
                                } else {
                                    log.info("Successfully removed duplicate manager")
                                    continuation.resume(returning: ())
                                }
                            }
                        }
                    } catch {
                        log.warning("Error removing duplicate manager: \(error)")
                        // Continue even if removal fails
                    }
                }

                // Update the kept manager's configuration
                if let protocolConfig = managerToKeep.protocolConfiguration as? NETunnelProviderProtocol {
                    protocolConfig.providerConfiguration = providerConfig
                    managerToKeep.protocolConfiguration = protocolConfig
                }

                // Save the updated configuration
                try await saveManagerToPreferences(managerToKeep, context: "kept manager configuration")

                return managerToKeep
            }
        }

        private static func createNewManager(providerConfig: [String: Any]? = nil) async throws -> NETransparentProxyManager {
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

    extension Collection where Element: NETransparentProxyManager {
        func firstMatching(bundleId: String) -> NETransparentProxyManager? {
            first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == bundleId
            }
        }
    }

    enum PlutoniumManagerError: Error {
        case saveFailed(Error)

        var localizedDescription: String {
            switch self {
            case let .saveFailed(error):
                "Failed to save transparent proxy manager: \(error.localizedDescription)"
            }
        }
    }

#endif
